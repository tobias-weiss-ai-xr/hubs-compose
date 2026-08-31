#!/usr/bin/env node
/**
 * create-element-rooms.mjs — generate the VR Periodensystem room catalog.
 *
 * Creates one "<Name>-Raum" per chemical element (118) via
 * POST /api/v1/hubs with user_data.chemistry = { name, symbol, z, pse_url },
 * exactly the contract the custom reticulum /api/v1/hubs/element/<sym>
 * endpoint serves (symbol matching is case-insensitive; symbol values are
 * validated server-side against the real element list).
 *
 * Idempotent: skips elements that already have >=1 room.
 * Rate-limit aware: reticulum 403/429s rapid anonymous creations —
 * we pace requests (~1.6s) and retry with backoff.
 *
 * After creation, wire scene + description via SQL (see run):
 *   UPDATE hubs SET scene_id=(scene_id of ElementRoom) — all element rooms
 *   share the "ElementRoom" scene (scene_sid mhezdAw), like the original
 *   Wasserstoff-Raum rooms.
 *
 * Usage: node scripts/create-element-rooms.mjs [--only He,Li] [--dry-run]
 */
const BASE = process.env.BASE || "https://hubs.chemie-lernen.org";
const DELAY_MS = Number(process.env.DELAY_MS || 1600);

// [z, symbol, German name]
const ELEMENTS = [
  [1,"H","Wasserstoff"],[2,"He","Helium"],[3,"Li","Lithium"],[4,"Be","Beryllium"],
  [5,"B","Bor"],[6,"C","Kohlenstoff"],[7,"N","Stickstoff"],[8,"O","Sauerstoff"],
  [9,"F","Fluor"],[10,"Ne","Neon"],[11,"Na","Natrium"],[12,"Mg","Magnesium"],
  [13,"Al","Aluminium"],[14,"Si","Silizium"],[15,"P","Phosphor"],[16,"S","Schwefel"],
  [17,"Cl","Chlor"],[18,"Ar","Argon"],[19,"K","Kalium"],[20,"Ca","Calcium"],
  [21,"Sc","Scandium"],[22,"Ti","Titan"],[23,"V","Vanadium"],[24,"Cr","Chrom"],
  [25,"Mn","Mangan"],[26,"Fe","Eisen"],[27,"Co","Cobalt"],[28,"Ni","Nickel"],
  [29,"Cu","Kupfer"],[30,"Zn","Zink"],[31,"Ga","Gallium"],[32,"Ge","Germanium"],
  [33,"As","Arsen"],[34,"Se","Selen"],[35,"Br","Brom"],[36,"Kr","Krypton"],
  [37,"Rb","Rubidium"],[38,"Sr","Strontium"],[39,"Y","Yttrium"],[40,"Zr","Zirkonium"],
  [41,"Nb","Niob"],[42,"Mo","Molybdän"],[43,"Tc","Technetium"],[44,"Ru","Ruthenium"],
  [45,"Rh","Rhodium"],[46,"Pd","Palladium"],[47,"Ag","Silber"],[48,"Cd","Cadmium"],
  [49,"In","Indium"],[50,"Sn","Zinn"],[51,"Sb","Antimon"],[52,"Te","Tellur"],
  [53,"I","Iod"],[54,"Xe","Xenon"],[55,"Cs","Cäsium"],[56,"Ba","Barium"],
  [57,"La","Lanthan"],[58,"Ce","Cer"],[59,"Pr","Praseodym"],[60,"Nd","Neodym"],
  [61,"Pm","Promethium"],[62,"Sm","Samarium"],[63,"Eu","Europium"],[64,"Gd","Gadolinium"],
  [65,"Tb","Terbium"],[66,"Dy","Dysprosium"],[67,"Ho","Holmium"],[68,"Er","Erbium"],
  [69,"Tm","Thulium"],[70,"Yb","Ytterbium"],[71,"Lu","Lutetium"],[72,"Hf","Hafnium"],
  [73,"Ta","Tantal"],[74,"W","Wolfram"],[75,"Re","Rhenium"],[76,"Os","Osmium"],
  [77,"Ir","Iridium"],[78,"Pt","Platin"],[79,"Au","Gold"],[80,"Hg","Quecksilber"],
  [81,"Tl","Thallium"],[82,"Pb","Blei"],[83,"Bi","Bismut"],[84,"Po","Polonium"],
  [85,"At","Astat"],[86,"Rn","Radon"],[87,"Fr","Francium"],[88,"Ra","Radium"],
  [89,"Ac","Actinium"],[90,"Th","Thorium"],[91,"Pa","Protactinium"],[92,"U","Uran"],
  [93,"Np","Neptunium"],[94,"Pu","Plutonium"],[95,"Am","Americium"],[96,"Cm","Curium"],
  [97,"Bk","Berkelium"],[98,"Cf","Californium"],[99,"Es","Einsteinium"],[100,"Fm","Fermium"],
  [101,"Md","Mendelevium"],[102,"No","Nobelium"],[103,"Lr","Lawrencium"],[104,"Rf","Rutherfordium"],
  [105,"Db","Dubnium"],[106,"Sg","Seaborgium"],[107,"Bh","Bohrium"],[108,"Hs","Hassium"],
  [109,"Mt","Meitnerium"],[110,"Ds","Darmstadtium"],[111,"Rg","Röntgenium"],[112,"Cn","Copernicium"],
  [113,"Nh","Nihonium"],[114,"Fl","Flerovium"],[115,"Mc","Moscovium"],[116,"Lv","Livermorium"],
  [117,"Ts","Tenness"],[118,"Og","Oganesson"],
];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const onlyIdx = args.indexOf("--only");
const only = onlyIdx !== -1 ? args[onlyIdx + 1]?.split(",").map((s) => s.trim()) : null;

async function existingCount(symbol) {
  try {
    const r = await fetch(`${BASE}/api/v1/hubs/element/${encodeURIComponent(symbol)}`);
    if (!r.ok) return -1; // endpoint error -> do not skip blindly
    const j = await r.json();
    return j?.pagination?.total_entries ?? j?.hubs?.length ?? 0;
  } catch { return -1; }
}

async function createRoom(sym, name, z) {
  const body = {
    hub: {
      name: `${name}-Raum`,
      user_data: {
        chemistry: {
          name,
          symbol: sym,
          z,
          pse_url: `https://pse.chemie-lernen.org/?element=${sym}`,
        },
      },
    },
  };
  for (let attempt = 1; attempt <= 4; attempt++) {
    const r = await fetch(`${BASE}/api/v1/hubs`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    });
    if (r.ok) return { ok: true, hub: await r.json() };
    if ((r.status === 403 || r.status === 429) && attempt < 4) {
      await sleep(DELAY_MS * attempt * attempt); // backoff on rate limit
      continue;
    }
    return { ok: false, status: r.status, text: (await r.text()).slice(0, 120) };
  }
}

let created = 0, skipped = 0, failed = 0;
for (const [z, sym, name] of ELEMENTS) {
  if (only && !only.includes(sym)) continue;
  const n = await existingCount(sym);
  if (n > 0) { skipped++; continue; }
  if (dryRun) { console.log(`  would create ${name}-Raum (${sym}, z=${z})`); created++; continue; }
  const res = await createRoom(sym, name, z);
  if (res.ok) {
    created++;
    console.log(`  ✓ ${String(z).padStart(3)} ${sym.padEnd(3)} ${name}-Raum -> ${res.hub.hub_id}`);
  } else {
    failed++;
    console.error(`  ✗ ${sym} ${name}: HTTP ${res.status} ${res.text}`);
  }
  await sleep(DELAY_MS);
}
console.log(`\ndone: created=${created} skipped=${skipped} failed=${failed}`);
if (failed > 0) process.exitCode = 1;
