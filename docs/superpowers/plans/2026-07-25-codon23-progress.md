# Codon 23: Progress Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real-time per-student progress tracking for chemistry VR labs — tracking element navigation, experiment completion, quiz scores, and time spent.

**Architecture:** Follows Codon 22 (Quiz) pattern: Ecto migration + schema in Reticulum, Phoenix channel handlers for upsert/query, JS wrapper methods in hub-channel.js, and React components for teacher/student views.

**Tech Stack:** Elixir/Ecto (Reticulum), PostgreSQL, Phoenix Channels, React (Hubs PSE)

---

## File Structure

### Reticulum (`hubs-cloud/community-edition/services/reticulum/`)
- **Create:** `priv/repo/migrations/20260725000001_create_user_progress.exs`
- **Create:** `lib/ret/user_progress.ex`
- **Modify:** `lib/ret_web/channels/hub_channel.ex` — 3 handlers + alias import

### Hubs (`hubs/`)
- **Modify:** `src/utils/hub-channel.js` — 3 methods + 2 event listeners
- **Create:** `src/react-components/room/ProgressTracker.js`
- **Create:** `src/react-components/room/ProgressPanel.js`
- **Create:** `src/react-components/room/ProgressPanel.scss`

### hubs-compose
- **Modify:** `docker-compose.yml` — no changes needed (same DB, schema migrations auto-run)

---

### Task 1: Migration — Create user_progress table

**Files:**
- Create: `priv/repo/migrations/20260725000001_create_user_progress.exs`

- [ ] **Write migration**

```elixir
defmodule Ret.Repo.Migrations.CreateUserProgress do
  use Ecto.Migration

  def change do
    create table(:user_progress, primary_key: false) do
      add :user_progress_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true
      add :account_id, references(:accounts, column: :account_id, on_delete: :delete_all)
      add :hub_id, references(:hubs, column: :hub_id, on_delete: :delete_all), null: false
      add :session_id, :text, null: false
      add :element_slug, :text, null: false
      add :element_type, :text, null: false
      add :status, :text, default: "visited", null: false
      add :score, :integer
      add :max_score, :integer
      add :time_spent_ms, :integer, default: 0
      add :visited_count, :integer, default: 1
      add :metadata, :map, default: fragment("'{}'::jsonb")
      timestamps()
    end

    create unique_index(:user_progress, [:account_id, :hub_id, :element_slug])
    create index(:user_progress, [:hub_id])
    create index(:user_progress, [:account_id])
    create index(:user_progress, [:session_id])
  end
end
```

Run: `mix ecto.migrate` (or let the Reticulum startup auto-run in Docker)

- [ ] **Commit**

```bash
git add priv/repo/migrations/20260725000001_create_user_progress.exs
git commit -m "feat: add user_progress migration"
```

---

### Task 2: Ecto schema — Ret.UserProgress

**Files:**
- Create: `lib/ret/user_progress.ex`

- [ ] **Write schema**

```elixir
defmodule Ret.UserProgress do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Ret.{Repo, UserProgress}

  @schema_prefix "ret0"
  @primary_key {:user_progress_id, :id, autogenerate: true}

  schema "user_progress" do
    belongs_to :account, Ret.Account, references: :account_id
    belongs_to :hub, Ret.Hub, references: :hub_id
    field :session_id, :string
    field :element_slug, :string
    field :element_type, :string
    field :status, :string, default: "visited"
    field :score, :integer
    field :max_score, :integer
    field :time_spent_ms, :integer, default: 0
    field :visited_count, :integer, default: 1
    field :metadata, :map, default: %{}

    timestamps()
  end

  @valid_statuses ~w(visited started completed)

  def changeset(progress, attrs) do
    progress
    |> cast(attrs, [:account_id, :hub_id, :session_id, :element_slug, :element_type, :status, :score, :max_score, :time_spent_ms, :visited_count, :metadata])
    |> validate_required([:hub_id, :session_id, :element_slug, :element_type])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:element_type, ~w(element experiment quiz))
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:hub_id)
  end

  def for_hub(hub_id) do
    Repo.all(
      from p in UserProgress,
        where: p.hub_id == ^hub_id,
        order_by: [asc: p.element_slug]
    )
  end

  def for_account_and_hub(account_id, hub_id) do
    Repo.all(
      from p in UserProgress,
        where: p.account_id == ^account_id and p.hub_id == ^hub_id,
        order_by: [asc: p.element_slug]
    )
  end

  def for_session_and_hub(session_id, hub_id) do
    Repo.all(
      from p in UserProgress,
        where: p.session_id == ^session_id and p.hub_id == ^hub_id,
        order_by: [asc: p.element_slug]
    )
  end
end
```

- [ ] **Commit**

```bash
git add lib/ret/user_progress.ex
git commit -m "feat: add UserProgress Ecto schema"
```

---

### Task 3: Channel handlers — track_progress, get_my_progress, get_room_progress

**Files:**
- Modify: `lib/ret_web/channels/hub_channel.ex`

Add `UserProgress` to the alias block and add 3 handlers after the quiz handlers.

- [ ] **Add UserProgress to alias block** (around line 16)

```elixir
    QuizAnswer,
    UserProgress,
    Repo,
```

- [ ] **Add channel handlers after the end_quiz handler** (after the `end_quiz` function)

```elixir
  def handle_in("track_progress", payload, socket) do
    hub = socket |> hub_for_socket
    account = Guardian.Phoenix.Socket.current_resource(socket)
    session_id = socket.assigns.session_id

    element_slug = payload["element_slug"]
    element_type = payload["element_type"] || "element"
    status = payload["status"] || "visited"

    account_id = if account, do: account.account_id, else: nil

    existing =
      if account_id do
        UserProgress.for_account_and_hub(account_id, hub.hub_id)
        |> Enum.find(&(&1.element_slug == element_slug))
      else
        UserProgress.for_session_and_hub(session_id, hub.hub_id)
        |> Enum.find(&(&1.element_slug == element_slug))
      end

    result =
      if existing do
        existing
        |> UserProgress.changeset(%{
          status: status,
          score: payload["score"] || existing.score,
          max_score: payload["max_score"] || existing.max_score,
          time_spent_ms: (existing.time_spent_ms || 0) + (payload["time_spent_ms"] || 0),
          visited_count: if(status == "visited", do: existing.visited_count + 1, else: existing.visited_count),
          metadata: payload["metadata"] || existing.metadata
        })
        |> Repo.update()
      else
        %UserProgress{}
        |> UserProgress.changeset(%{
          account_id: account_id,
          hub_id: hub.hub_id,
          session_id: session_id,
          element_slug: element_slug,
          element_type: element_type,
          status: status,
          score: payload["score"],
          max_score: payload["max_score"],
          time_spent_ms: payload["time_spent_ms"] || 0,
          visited_count: 1,
          metadata: payload["metadata"] || %{}
        })
        |> Repo.insert()
      end

    case result do
      {:ok, progress} ->
        broadcast!(socket, "progress_updated", %{
          account_id: account_id,
          session_id: session_id,
          element_slug: progress.element_slug,
          element_type: progress.element_type,
          status: progress.status,
          score: progress.score,
          max_score: progress.max_score,
          time_spent_ms: progress.time_spent_ms,
          visited_count: progress.visited_count
        })
        {:reply, {:ok, %{element_slug: progress.element_slug, status: progress.status}}, socket}

      {:error, changeset} ->
        {:reply, {:error, %{message: "Failed to track progress", errors: changeset.errors}}, socket}
    end
  end

  def handle_in("get_my_progress", _payload, socket) do
    hub = socket |> hub_for_socket
    account = Guardian.Phoenix.Socket.current_resource(socket)
    session_id = socket.assigns.session_id

    entries =
      if account do
        UserProgress.for_account_and_hub(account.account_id, hub.hub_id)
      else
        UserProgress.for_session_and_hub(session_id, hub.hub_id)
      end

    {:reply, {:ok, %{entries: Enum.map(entries, &progress_to_map/1)}}, socket}
  end

  def handle_in("get_room_progress", _payload, socket) do
    hub = socket |> hub_for_socket
    account = Guardian.Phoenix.Socket.current_resource(socket)

    if account && account |> can?(:update_hub, hub) do
      entries = UserProgress.for_hub(hub.hub_id)

      grouped =
        entries
        |> Enum.group_by(fn p ->
          if p.account_id, do: {:account, p.account_id}, else: {:session, p.session_id}
        end)
        |> Enum.map(fn {key, group} ->
          {identity_name, _account_id} =
            case key do
              {:account, id} ->
                account = Repo.get(Ret.Account, id)
                {if(account, do: account.name, else: "Anonymous"), id}
              {:session, sid} ->
                {sid, nil}
            end

          %{
            account_id: (case key do {:account, id} -> id; _ -> nil end),
            session_id: (case key do {:session, sid} -> sid; _ -> nil end),
            identity_name: identity_name,
            entries: Enum.map(group, &progress_to_map/1)
          }
        end)

      {:reply, {:ok, %{students: grouped}}, socket}
    else
      {:reply, {:error, %{message: "Unauthorized"}}, socket}
    end
  end

  defp progress_to_map(progress) do
    %{
      element_slug: progress.element_slug,
      element_type: progress.element_type,
      status: progress.status,
      score: progress.score,
      max_score: progress.max_score,
      time_spent_ms: progress.time_spent_ms,
      visited_count: progress.visited_count,
      metadata: progress.metadata,
      updated_at: progress.updated_at
    }
  end
```

- [ ] **Commit**

```bash
git add lib/ret_web/channels/hub_channel.ex
git commit -m "feat: add progress tracking channel handlers"
```

---

### Task 4: Frontend — hub-channel.js wrapper methods

**Files:**
- Modify: `src/utils/hub-channel.js`

Add 3 push methods and 2 event listeners after the quiz methods (after line 505).

- [ ] **Add progress methods**

```javascript
  trackProgress = (elementSlug, elementType, data = {}) => {
    return new Promise((resolve, reject) => {
      this.channel
        .push("track_progress", { element_slug: elementSlug, element_type: elementType, ...data })
        .receive("ok", resolve)
        .receive("error", reject);
    });
  };

  getMyProgress = () => {
    return new Promise((resolve, reject) => {
      this.channel
        .push("get_my_progress", {})
        .receive("ok", resolve)
        .receive("error", reject);
    });
  };

  getRoomProgress = () => {
    return new Promise((resolve, reject) => {
      this.channel
        .push("get_room_progress", {})
        .receive("ok", resolve)
        .receive("error", reject);
    });
  };

  onProgressUpdated = handler => {
    this.channel.on("progress_updated", handler);
  };
```

- [ ] **Commit**

```bash
git add src/utils/hub-channel.js
git commit -m "feat: add progress tracking hub-channel methods"
```

---

### Task 5: Frontend — ProgressTracker auto-tracking module

**Files:**
- Create: `src/react-components/room/ProgressTracker.js`

Auto-tracks element navigation, quiz completion, and time spent. Hooks into existing events.

- [ ] **Write ProgressTracker module**

```javascript
import { useEffect, useRef, useCallback } from "react";

const ELEMENT_NAV_EVENT = "navigate_element";
const QUIZ_STARTED_EVENT = "quiz_started";
const QUIZ_ENDED_EVENT = "quiz_ended";

export default function useProgressTracker(channel, elementSlug, elementType) {
  const startTime = useRef(null);
  const currentSlug = useRef(null);

  const track = useCallback(
    (slug, type, data = {}) => {
      if (!channel || !slug) return;
      channel.trackProgress(slug, type, data).catch(() => {});
    },
    [channel]
  );

  useEffect(() => {
    if (!channel) return;

    if (elementSlug && elementSlug !== currentSlug.current) {
      if (currentSlug.current) {
        const elapsed = startTime.current ? Date.now() - startTime.current : 0;
        track(currentSlug.current, elementType, {
          status: "visited",
          time_spent_ms: elapsed
        });
      }
      currentSlug.current = elementSlug;
      startTime.current = Date.now();
      track(elementSlug, elementType, { status: "started" });
    }

    return () => {
      if (currentSlug.current && startTime.current) {
        const elapsed = Date.now() - startTime.current;
        track(currentSlug.current, elementType, {
          status: "visited",
          time_spent_ms: elapsed
        });
      }
    };
  }, [channel, elementSlug, elementType, track]);

  return { track };
}
```

- [ ] **Commit**

```bash
git add src/react-components/room/ProgressTracker.js
git commit -m "feat: add ProgressTracker auto-tracking hook"
```

---

### Task 6: Frontend — ProgressPanel component

**Files:**
- Create: `src/react-components/room/ProgressPanel.js`
- Create: `src/react-components/room/ProgressPanel.scss`

Teacher view: per-student completion table with progress bars per element. Student view: own checklist with status badges.

- [ ] **Write ProgressPanel.scss**

```scss
.panel {
  padding: 16px;
}

.header {
  font-size: 16px;
  font-weight: 600;
  margin-bottom: 12px;
}

.studentList {
  margin-bottom: 16px;
}

.studentCard {
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  padding: 12px;
  margin-bottom: 8px;
  background: #f9fafb;
}

.studentName {
  font-weight: 600;
  margin-bottom: 8px;
  font-size: 14px;
}

.elementList {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.elementRow {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 4px 0;
  font-size: 13px;
}

.elementName {
  flex: 1;
}

.badge {
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
}

.badgeVisited {
  background: #fef3c7;
  color: #92400e;
}

.badgeStarted {
  background: #dbeafe;
  color: #1e40af;
}

.badgeCompleted {
  background: #d1fae5;
  color: #065f46;
}

.score {
  font-size: 12px;
  color: #6b7280;
  margin-left: 8px;
}

.time {
  font-size: 11px;
  color: #9ca3af;
  margin-left: 8px;
}

.noData {
  color: #9ca3af;
  text-align: center;
  padding: 24px;
}

.toggleBtn {
  background: none;
  border: 1px solid #d1d5db;
  border-radius: 4px;
  padding: 4px 12px;
  cursor: pointer;
  font-size: 12px;
  margin-bottom: 8px;
}
```

- [ ] **Write ProgressPanel.js**

```javascript
import React, { useCallback, useEffect, useState } from "react";
import PropTypes from "prop-types";
import { Button } from "../input/Button";
import { Column } from "../layout/Column";
import styles from "./ProgressPanel.scss";

const STATUS_BADGE = {
  visited: styles.badgeVisited,
  started: styles.badgeStarted,
  completed: styles.badgeCompleted
};

const STATUS_LABEL = { visited: "Visited", started: "In Progress", completed: "Done" };

function formatTime(ms) {
  if (!ms) return "";
  const secs = Math.floor(ms / 1000);
  if (secs < 60) return `${secs}s`;
  return `${Math.floor(secs / 60)}m ${secs % 60}s`;
}

function StudentProgressEntry({ entry }) {
  return (
    <div className={styles.elementRow}>
      <span className={styles.elementName}>{entry.element_slug}</span>
      <span className={`${styles.badge} ${STATUS_BADGE[entry.status] || ""}`}>
        {STATUS_LABEL[entry.status] || entry.status}
      </span>
      {entry.max_score != null && (
        <span className={styles.score}>{entry.score ?? 0}/{entry.max_score}</span>
      )}
      <span className={styles.time}>{formatTime(entry.time_spent_ms)}</span>
    </div>
  );
}

function StudentCard({ student, expanded, onToggle }) {
  const entries = student.entries || [];
  const completed = entries.filter(e => e.status === "completed").length;
  const pct = entries.length > 0 ? Math.round((completed / entries.length) * 100) : 0;

  return (
    <div className={styles.studentCard}>
      <div className={styles.studentName}>
        {student.identity_name} — {completed}/{entries.length} ({pct}%)
      </div>
      {expanded && (
        <div className={styles.elementList}>
          {entries.map(e => (
            <StudentProgressEntry key={e.element_slug} entry={e} />
          ))}
        </div>
      )}
      {entries.length > 0 && (
        <button className={styles.toggleBtn} onClick={onToggle}>
          {expanded ? "Collapse" : "Details"}
        </button>
      )}
    </div>
  );
}

function TeacherView({ channel }) {
  const [students, setStudents] = useState([]);
  const [expanded, setExpanded] = useState({});

  const load = useCallback(async () => {
    try {
      const res = await channel.getRoomProgress();
      setStudents(res.students || []);
    } catch { /* ignore */ }
  }, [channel]);

  useEffect(() => {
    load();
    channel.onProgressUpdated(load);
  }, [channel, load]);

  const toggle = useCallback(id => {
    setExpanded(prev => ({ ...prev, [id]: !prev[id] }));
  }, []);

  if (students.length === 0) {
    return <div className={styles.noData}>No student activity yet</div>;
  }

  return (
    <div className={styles.panel}>
      <div className={styles.header}>Room Progress</div>
      <div className={styles.studentList}>
        {students.map((s, i) => (
          <StudentCard
            key={s.account_id || s.session_id || i}
            student={s}
            expanded={expanded[s.account_id || s.session_id || i]}
            onToggle={() => toggle(s.account_id || s.session_id || i)}
          />
        ))}
      </div>
      <Button onClick={load}>Refresh</Button>
    </div>
  );
}

function StudentView({ channel }) {
  const [entries, setEntries] = useState([]);

  useEffect(() => {
    channel.getMyProgress().then(res => setEntries(res.entries || [])).catch(() => {});
    channel.onProgressUpdated(() => {
      channel.getMyProgress().then(res => setEntries(res.entries || [])).catch(() => {});
    });
  }, [channel]);

  const completed = entries.filter(e => e.status === "completed").length;
  const pct = entries.length > 0 ? Math.round((completed / entries.length) * 100) : 0;

  return (
    <div className={styles.panel}>
      <div className={styles.header}>My Progress — {completed}/{entries.length} ({pct}%)</div>
      <div className={styles.elementList}>
        {entries.map(e => (
          <StudentProgressEntry key={e.element_slug} entry={e} />
        ))}
      </div>
      {entries.length === 0 && <div className={styles.noData}>No progress yet</div>}
    </div>
  );
}

export default function ProgressPanel({ channel, isTeacher, onClose }) {
  return (
    <Column>
      {isTeacher ? <TeacherView channel={channel} /> : <StudentView channel={channel} />}
      <Button onClick={onClose}>Close</Button>
    </Column>
  );
}

ProgressPanel.propTypes = {
  channel: PropTypes.object.isRequired,
  isTeacher: PropTypes.bool,
  onClose: PropTypes.func.isRequired
};
```

- [ ] **Commit**

```bash
git add src/react-components/room/ProgressPanel.js src/react-components/room/ProgressPanel.scss
git commit -m "feat: add ProgressPanel teacher/student components"
```

---

### Task 7: Wire ProgressPanel into room UI

**Files:**
- Modify: `src/react-components/ui-root.js`

Add a "Progress" item in the "Room" section of the moreMenu, and a `sidebarId === "progress"` conditional render.

- [ ] **Import ProgressPanel and Document icon** (around line 99, after the other imports)

```javascript
import { ReactComponent as DocumentIcon } from "./icons/Document.svg";
import ProgressPanel from "./room/ProgressPanel";
```

- [ ] **Add sidebarId render for progress** (after the ecs-debug sidebar at line 1588)

```javascript
                      {this.state.sidebarId === "progress" && (
                        <ProgressPanel
                          channel={this.props.hubChannel}
                          isTeacher={this.props.hubChannel.can("update_hub")}
                          onClose={() => this.setSidebar(null)}
                        />
                      )}
```

- [ ] **Add "Progress" item to moreMenu's room section** (around line 1248, after "streamer-mode" item)

```javascript
          entered && {
            id: "progress",
            label: "Progress",
            icon: DocumentIcon,
            onClick: () => this.setSidebar("progress")
          },
```

- [ ] **Commit**

```bash
git add src/react-components/ui-root.js src/react-components/room/ProgressPanel.js src/react-components/room/ProgressPanel.scss
git commit -m "feat: wire ProgressPanel into room UI"
```
