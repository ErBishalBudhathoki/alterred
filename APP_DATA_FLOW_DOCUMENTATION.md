# Neuropilot App - Complete Data Flow Documentation

## Overview
This document maps the complete data flow across all 22 screens in the Neuropilot Flutter app, from splash screen through every feature. It includes state management, API calls, data generation, and inter-screen communication.

---

## 1. SPLASH SCREEN → LOGIN/MAIN SCREEN

**File**: `lib/screens/splash_screen.dart`

### Data Flow
```
App Start (main.dart)
  ↓
Firebase Initialization
  ↓
SplashScreen (animated loading)
  ↓
navigationProvider checks auth status
  ├─ authInitializedProvider → Firebase initialized?
  ├─ authUserProvider → Current user exists?
  └─ idTokenSyncProvider → Fetch ID token
  ↓
Route Decision:
  ├─ User authenticated → MainScreen (/chat)
  └─ User not authenticated → LoginScreen (/login)
```

### Data Generated
- **Session ID**: Generated via `Uuid()` if new session
- **Auth Token**: Fetched from Firebase ID token
- **Country Code**: Determined via GPS or IP geolocation

### Example Flow
```dart
// User opens app
// SplashScreen listens to navigationProvider
ref.listen<AsyncValue<String>>(navigationProvider, (prev, next) {
  if (next.hasValue) {
    // Navigate to /chat or /login based on auth status
    Navigator.of(context).pushNamedAndRemoveUntil(next.value!, (r) => false);
  }
});

// Behind the scenes:
// 1. authInitializedProvider → Firebase.initializeApp()
// 2. authUserProvider → FirebaseAuth.instance.authStateChanges()
// 3. If user exists → idTokenSyncProvider fetches token
// 4. tokenProvider updated with ID token
```

---

## 2. LOGIN SCREEN

**File**: `lib/screens/login_screen.dart`

### Data Flow
```
LoginScreen
  ├─ Email/Password Input
  │   ↓
  │   AuthService.signInWithEmail(email, password)
  │   ↓
  │   FirebaseAuth.signInWithEmailAndPassword()
  │   ↓
  │   authUserProvider updates (stream)
  │   ↓
  │   idTokenSyncProvider fetches token
  │   ↓
  │   tokenProvider updated
  │   ↓
  │   Navigate to MainScreen
  │
  └─ Google Sign-In Button
      ↓
      AuthService.signInWithGoogle()
      ↓
      GoogleSignIn.signIn() (platform-specific)
      ↓
      FirebaseAuth.signInWithCredential()
      ↓
      Same flow as above
```

### Data Generated
- **User Credentials**: Email + Password OR Google OAuth token
- **Firebase User Object**: Contains uid, email, displayName
- **ID Token**: JWT token for backend API calls

### Example
```dart
// User enters email: user@example.com, password: pass123
// Taps "Sign In"

final authController = AuthController(ref);
await authController.signInEmail('user@example.com', 'pass123');

// Behind scenes:
// 1. FirebaseAuth.signInWithEmailAndPassword()
// 2. Returns UserCredential with User object
// 3. authUserProvider stream emits new User
// 4. idTokenSyncProvider runs → fetches ID token
// 5. tokenProvider.notifier.state = token
// 6. navigationProvider re-evaluates → returns '/chat'
// 7. MainScreen displayed
```

---

## 3. SIGNUP SCREEN

**File**: `lib/screens/signup_screen.dart`

### Data Flow
```
SignupScreen
  ├─ Email Input
  ├─ Password Input
  ├─ Display Name Input
  ↓
  AuthService.signUpWithEmail(email, password, displayName)
  ↓
  FirebaseAuth.createUserWithEmailAndPassword()
  ↓
  User.updateDisplayName(displayName)
  ↓
  Backend: Create user profile document
  ↓
  Auto sign-in (same as login flow)
  ↓
  MainScreen
```

### Data Generated
- **New User Account**: Firebase Auth user record
- **User Profile**: Display name, email, uid
- **Initial Settings**: Default UserSettings created

### Example
```dart
// User enters:
// Email: newuser@example.com
// Password: SecurePass123
// Display Name: John Doe

await authController.signUpEmail(
  'newuser@example.com',
  'SecurePass123',
  displayName: 'John Doe'
);

// Backend creates:
// - Firebase Auth user
// - Firestore document: /users/{uid}/profile
// - Default settings document
```

---

## 4. MAIN SCREEN (Navigation Hub)

**File**: `lib/screens/main_screen.dart`

### Data Flow
```
MainScreen (6-tab bottom navigation)
  ├─ navigationIndexProvider (StateProvider)
  │   └─ Tracks selected tab (0-5)
  │
  ├─ Tab 0: DashboardScreen
  ├─ Tab 1: MetricsScreen
  ├─ Tab 2: ObservabilityScreen
  ├─ Tab 3: ProfileScreen
  ├─ Tab 4: ExternalBrainScreen
  └─ Tab 5: SettingsScreen
```

### Data Flow
```dart
// User taps tab icon
ref.read(navigationIndexProvider.notifier).state = tabIndex;

// IndexedStack rebuilds with selected screen
// Previous screens maintain state (not disposed)
```

---

## 5. DASHBOARD SCREEN (Home)

**File**: `lib/screens/dashboard_screen.dart`

### Data Flow
```
DashboardScreen
  ├─ Energy Level Display
  │   ├─ energyStoreProvider
  │   ├─ Fetches: GET /metrics/energy
  │   └─ Updates: Every 5 minutes or on manual refresh
  │
  ├─ Task List (Today's Tasks)
  │   ├─ tasksProvider
  │   ├─ Fetches: GET /tasks/
  │   ├─ Filters: status != 'completed'
  │   └─ Sorted by priority
  │
  ├─ Quick Actions
  │   ├─ "Start Chat" → ChatScreen
  │   ├─ "Create Task" → CreateTaskScreen
  │   ├─ "Voice Mode" → VoiceModeScreen
  │   └─ "Focus Session" → FocusSessionScreen
  │
  └─ Recent Chat Sessions
      ├─ chatSessionsProvider
      ├─ Fetches: SharedPreferences + Firestore
      └─ Shows last 3 sessions
```

### Data Generated
- **Energy Metrics**: Calculated from user activity, sleep, stress
- **Task Summary**: Count of pending/completed tasks
- **Session Preview**: Last chat session title + preview text

### Example
```dart
// Dashboard loads
// 1. energyStoreProvider fetches energy level
//    GET /metrics/energy → { energy: 75, status: 'high' }
//
// 2. tasksProvider fetches tasks
//    GET /tasks/ → [
//      { id: '1', title: 'Review docs', priority: 'high', status: 'pending' },
//      { id: '2', title: 'Email client', priority: 'medium', status: 'pending' }
//    ]
//
// 3. chatSessionsProvider loads from local storage
//    SharedPreferences.getString('chat_sessions') → [
//      { id: 'sess_1', title: 'Project Planning', lastActivity: '2025-12-22T10:30:00Z' }
//    ]
//
// UI displays:
// - Energy: 75% (green indicator)
// - Tasks: 2 pending
// - Recent: "Project Planning" session
```



---

## 6. CHAT SCREEN (Main AI Interface)

**File**: `lib/screens/chat_screen.dart`

### Data Flow
```
ChatScreen
  ├─ User Types Message
  │   ├─ Input captured in TextField
  │   └─ Stored in local state
  │
  ├─ User Sends Message
  │   ├─ Message added to chatStore
  │   ├─ Stored in: SharedPreferences + Firestore
  │   ├─ chatSessionsProvider invalidated
  │   └─ UI updates with user message
  │
  ├─ API Call to Backend
  │   ├─ ApiClient.chatRespond(message, sessionId, context)
  │   ├─ POST /chat/respond
  │   ├─ Headers include: Authorization, X-Client-Timezone
  │   └─ Body: { message, session_id, context_memory }
  │
  ├─ Backend Processing
  │   ├─ Vertex AI / Gemini API call
  │   ├─ Context retrieval from memory
  │   ├─ Response generation
  │   └─ Metrics logging
  │
  ├─ Response Received
  │   ├─ Assistant message added to chatStore
  │   ├─ Stored in: SharedPreferences + Firestore
  │   ├─ TTS triggered (if voice mode enabled)
  │   └─ UI updates with assistant response
  │
  └─ Voice Mode (Optional)
      ├─ SpeechService.listen() (STT)
      ├─ Partial text updates displayed
      ├─ On speech end → send message
      └─ TtsService.speak() (TTS) plays response
```

### Data Generated
- **ChatMessage**: { role: 'user'|'assistant', content: string, timestamp }
- **ChatSession**: Updated lastActivity, unreadCount
- **Context Memory**: Extracted keywords from conversation

### Example
```dart
// User types: "Help me prioritize my tasks"
// Taps send button

// 1. Message added locally
ChatMessage userMsg = ChatMessage(
  role: 'user',
  content: 'Help me prioritize my tasks',
  time: DateTime.now()
);
await chatStore.addMessage(sessionId, userMsg);

// 2. API call
final response = await apiClient.chatRespond(
  message: 'Help me prioritize my tasks',
  sessionId: 'sess_abc123',
  context: contextMemory.retrieve('tasks')
);

// 3. Backend response
// POST /chat/respond
// Response: {
//   "response": "I'll help you prioritize. Let me fetch your tasks...",
//   "actions": [{ "type": "fetch_tasks" }],
//   "metadata": { "model": "gemini-2.0-flash" }
// }

// 4. Assistant message added
ChatMessage assistantMsg = ChatMessage(
  role: 'assistant',
  content: response['response'],
  time: DateTime.now()
);
await chatStore.addMessage(sessionId, assistantMsg);

// 5. If voice enabled
await ttsService.speak(response['response']);

// UI updates with both messages in conversation
```

---

## 7. CHAT HISTORY SCREEN

**File**: `lib/screens/chat_history_screen.dart`

### Data Flow
```
ChatHistoryScreen
  ├─ Load Sessions
  │   ├─ chatSessionsProvider
  │   ├─ Fetches: SharedPreferences + Firestore
  │   ├─ Pagination: offset=0, limit=20
  │   └─ Sorted by lastActivity (newest first)
  │
  ├─ Search Sessions
  │   ├─ chatSearchQueryProvider (StateProvider)
  │   ├─ Filters sessions by title/preview
  │   └─ Real-time filtering
  │
  ├─ Select Session
  │   ├─ Load messages for session
  │   ├─ Fetch from: SharedPreferences cache
  │   ├─ If not cached → Firestore
  │   └─ Navigate to ChatScreen with sessionId
  │
  ├─ Delete Session
  │   ├─ chatStore.deleteSession(sessionId)
  │   ├─ Remove from: SharedPreferences + Firestore
  │   ├─ chatSessionsProvider invalidated
  │   └─ UI updates
  │
  └─ Create New Session
      ├─ chatStore.createSession()
      ├─ Generate new UUID
      ├─ Store in: SharedPreferences + Firestore
      └─ Navigate to ChatScreen
```

### Data Generated
- **ChatSession List**: Array of sessions with metadata
- **Search Results**: Filtered session list
- **Session Preview**: First 80 chars of last message

### Example
```dart
// ChatHistoryScreen loads
// 1. Fetch all sessions
final sessions = await chatStore.listSessions(limit: 20);
// Returns: [
//   {
//     id: 'sess_1',
//     title: 'Project Planning',
//     createdAt: '2025-12-20T14:30:00Z',
//     lastActivity: '2025-12-22T10:15:00Z',
//     unreadCount: 0,
//     preview: 'Let me break down the project timeline...'
//   },
//   { ... }
// ]

// 2. User searches for "project"
ref.read(chatSearchQueryProvider.notifier).state = 'project';
// Filtered: [{ id: 'sess_1', ... }]

// 3. User taps session
// Load messages for sess_1
final messages = await chatStore.getMessages('sess_1');
// Navigate to ChatScreen with sessionId

// 4. User deletes session
await chatStore.deleteSession('sess_1');
// Removed from SharedPreferences and Firestore
// chatSessionsProvider invalidated → UI refreshes
```



---

## 8. CREATE TASK SCREEN

**File**: `lib/screens/create_task_screen.dart`

### Data Flow
```
CreateTaskScreen
  ├─ Form Inputs
  │   ├─ Title (required)
  │   ├─ Description (optional)
  │   ├─ Due Date (date picker)
  │   ├─ Priority (dropdown: low/medium/high/critical)
  │   ├─ Effort (dropdown: low/medium/high)
  │   └─ Status (default: pending)
  │
  ├─ User Submits
  │   ├─ Validate form
  │   ├─ Create Task object
  │   └─ tasksProvider.notifier.createTask(task)
  │
  ├─ API Call
  │   ├─ TaskService.createTask(task)
  │   ├─ POST /tasks/
  │   ├─ Body: { title, description, dueDate, priority, effort, status }
  │   └─ Returns: Task with generated id
  │
  ├─ Backend Processing
  │   ├─ Validate task data
  │   ├─ Store in database
  │   ├─ Generate task ID
  │   └─ Log to metrics
  │
  ├─ Update Local State
  │   ├─ tasksProvider invalidated
  │   ├─ Refresh task list
  │   └─ New task appears in list
  │
  └─ Navigation
      ├─ Pop screen
      └─ Return to Dashboard or TaskList
```

### Data Generated
- **Task Object**: { id, title, description, dueDate, priority, effort, status, createdAt }
- **Task ID**: Generated by backend (UUID or auto-increment)
- **Timestamp**: createdAt set to current time

### Example
```dart
// User fills form:
// Title: "Review Q1 Budget"
// Description: "Review and approve Q1 budget proposal"
// Due Date: 2025-12-31
// Priority: "high"
// Effort: "medium"

final task = Task(
  title: 'Review Q1 Budget',
  description: 'Review and approve Q1 budget proposal',
  dueDate: DateTime(2025, 12, 31),
  priority: 'high',
  effort: 'medium',
  status: 'pending',
  createdAt: DateTime.now()
);

// User taps "Create Task"
await ref.read(tasksProvider.notifier).createTask(task);

// Behind scenes:
// 1. TaskService.createTask(task)
// 2. POST /tasks/ with task.toJson()
// 3. Backend returns: { id: 'task_xyz789', ...task, createdAt: '2025-12-22T...' }
// 4. tasksProvider invalidated
// 5. tasksProvider.refreshTasks() called
// 6. GET /tasks/ fetches updated list
// 7. UI updates with new task in list
// 8. Screen pops, returns to Dashboard
```

---

## 9. TASK PRIORITIZATION SCREEN

**File**: `lib/screens/task_prioritization_screen.dart`

### Data Flow
```
TaskPrioritizationScreen
  ├─ Load Tasks
  │   ├─ tasksProvider
  │   ├─ Filter: status = 'pending'
  │   └─ Sort by: current priority
  │
  ├─ AI Prioritization Request
  │   ├─ Collect all pending tasks
  │   ├─ Include: energy level, time available, deadlines
  │   ├─ ApiClient.prioritizeTasks(tasks, context)
  │   ├─ POST /tasks/prioritize
  │   └─ Body: { tasks, energy_level, available_hours }
  │
  ├─ Backend AI Processing
  │   ├─ Vertex AI analyzes tasks
  │   ├─ Considers: effort, priority, deadlines, energy
  │   ├─ Generates: ranked task list with reasoning
  │   └─ Returns: { prioritized_tasks, reasoning }
  │
  ├─ Display Results
  │   ├─ Show ranked task list
  │   ├─ Display AI reasoning for each
  │   └─ Allow manual reordering
  │
  ├─ User Accepts/Modifies
  │   ├─ Update task priorities
  │   ├─ For each modified task:
  │   │   ├─ tasksProvider.notifier.updateTask(task)
  │   │   ├─ PUT /tasks/{id}
  │   │   └─ Update priority field
  │   └─ tasksProvider invalidated
  │
  └─ Navigation
      └─ Return to Dashboard
```

### Data Generated
- **Prioritized Task List**: Ranked by AI algorithm
- **Reasoning**: Explanation for each ranking
- **Updated Priorities**: New priority values for tasks

### Example
```dart
// TaskPrioritizationScreen loads
// 1. Fetch pending tasks
final tasks = await taskService.getTasks();
// [
//   { id: '1', title: 'Review docs', priority: 'medium', effort: 'low', dueDate: '2025-12-25' },
//   { id: '2', title: 'Fix bug', priority: 'high', effort: 'high', dueDate: '2025-12-23' },
//   { id: '3', title: 'Email client', priority: 'low', effort: 'low', dueDate: '2025-12-30' }
// ]

// 2. Get energy level
final energy = await metricsProvider.getEnergyLevel();
// { level: 75, status: 'high' }

// 3. Request AI prioritization
final result = await apiClient.prioritizeTasks(
  tasks: tasks,
  energyLevel: 75,
  availableHours: 4
);

// Backend response:
// {
//   "prioritized_tasks": [
//     { id: '2', title: 'Fix bug', priority: 'critical', reasoning: 'Urgent deadline, high impact' },
//     { id: '1', title: 'Review docs', priority: 'high', reasoning: 'Due soon, medium effort' },
//     { id: '3', title: 'Email client', priority: 'medium', reasoning: 'Low effort, can defer' }
//   ]
// }

// 4. User accepts prioritization
for (var task in prioritizedTasks) {
  await ref.read(tasksProvider.notifier).updateTask(task);
}

// 5. Each update:
// PUT /tasks/{id} with new priority
// tasksProvider invalidated
// UI refreshes with new order
```



---

## 10. METRICS SCREEN

**File**: `lib/screens/metrics_screen.dart`

### Data Flow
```
MetricsScreen
  ├─ Load Overview Metrics
  │   ├─ metricsProvider
  │   ├─ ApiClient.metricsOverview()
  │   ├─ GET /metrics/overview
  │   └─ Returns: Daily summary stats
  │
  ├─ Display Sections
  │   ├─ Energy Levels (chart)
  │   │   ├─ GET /metrics/daily/{dateKey}
  │   │   ├─ Shows: Energy over time
  │   │   └─ Data points: Hourly or daily
  │   │
  │   ├─ Stress Levels (chart)
  │   │   ├─ GET /metrics/stress
  │   │   ├─ Shows: Stress trend
  │   │   └─ Data points: Manual logs + inferred
  │   │
  │   ├─ Task Completion Rate
  │   │   ├─ Calculated from: tasksProvider
  │   │   ├─ Formula: completed / total
  │   │   └─ Shows: Percentage + trend
  │   │
  │   ├─ Focus Sessions
  │   │   ├─ GET /metrics/focus-sessions
  │   │   ├─ Shows: Total hours, sessions count
  │   │   └─ Data: Last 7 days
  │   │
  │   └─ Strategy Effectiveness
  │       ├─ GET /metrics/strategies
  │       ├─ Shows: Which strategies worked
  │       └─ Data: Success rate per strategy
  │
  ├─ Date Range Selection
  │   ├─ User selects: Today/Week/Month
  │   ├─ metricsDateRangeProvider (StateProvider)
  │   └─ Refetch data for range
  │
  └─ Manual Logging
      ├─ "Log Stress" button
      ├─ Opens dialog: stress level (1-10)
      ├─ ApiClient.logStress(level, context)
      ├─ POST /metrics/stress
      └─ Metrics updated
```

### Data Generated
- **Daily Metrics**: { date, energy, stress, tasksCompleted, focusHours }
- **Trends**: Energy/stress over time
- **Statistics**: Averages, peaks, patterns

### Example
```dart
// MetricsScreen loads
// 1. Fetch overview
final overview = await apiClient.metricsOverview();
// {
//   "today": {
//     "energy_avg": 72,
//     "stress_avg": 35,
//     "tasks_completed": 3,
//     "focus_hours": 2.5
//   },
//   "week": {
//     "energy_avg": 68,
//     "stress_avg": 42,
//     "tasks_completed": 18,
//     "focus_hours": 12
//   }
// }

// 2. Fetch daily metrics for chart
final dailyMetrics = await apiClient.getDailyMetrics('2025-12-22');
// {
//   "data": [
//     { "hour": 8, "energy": 60, "stress": 40 },
//     { "hour": 10, "energy": 75, "stress": 30 },
//     { "hour": 14, "energy": 65, "stress": 50 },
//     { "hour": 18, "energy": 55, "stress": 60 }
//   ]
// }

// 3. User logs stress
await apiClient.logStress(7, context: 'Difficult meeting');
// POST /metrics/stress
// { level: 7, context: 'Difficult meeting', timestamp: '2025-12-22T14:30:00Z' }

// 4. Metrics updated
// metricsProvider invalidated
// Charts refresh with new data
```

---

## 11. OBSERVABILITY SCREEN

**File**: `lib/screens/observability_screen.dart`

### Data Flow
```
ObservabilityScreen
  ├─ System Health Check
  │   ├─ ApiClient.health()
  │   ├─ GET /health
  │   └─ Returns: { status, uptime, services }
  │
  ├─ Display Sections
  │   ├─ Backend Status
  │   │   ├─ Status: Online/Offline
  │   │   ├─ Response Time
  │   │   └─ Last Check: timestamp
  │   │
  │   ├─ Firebase Status
  │   │   ├─ Auth: Connected/Disconnected
  │   │   ├─ Firestore: Sync status
  │   │   └─ Storage: Available space
  │   │
  │   ├─ API Endpoints
  │   │   ├─ Chat API: Status
  │   │   ├─ Tasks API: Status
  │   │   ├─ Metrics API: Status
  │   │   └─ Calendar API: Status
  │   │
  │   ├─ Network Info
  │   │   ├─ Connection Type: WiFi/Cellular
  │   │   ├─ Signal Strength
  │   │   └─ Latency
  │   │
  │   └─ App Logs
  │       ├─ Recent errors
  │       ├─ Warnings
  │       └─ Info messages
  │
  ├─ Refresh Button
  │   ├─ Re-run all health checks
  │   └─ Update all statuses
  │
  └─ Debug Mode (if enabled)
      ├─ Show detailed logs
      ├─ API request/response bodies
      └─ Timing information
```

### Data Generated
- **Health Status**: { status, timestamp, responseTime }
- **Service Statuses**: Array of service health checks
- **Network Info**: Connection type, signal, latency

### Example
```dart
// ObservabilityScreen loads
// 1. Health check
final health = await apiClient.health();
// {
//   "status": "healthy",
//   "uptime": 86400,
//   "services": {
//     "auth": "ok",
//     "firestore": "ok",
//     "vertex_ai": "ok",
//     "calendar": "ok"
//   },
//   "response_time_ms": 45
// }

// 2. Firebase status
final firebaseStatus = FirebaseAuth.instance.currentUser != null ? 'connected' : 'disconnected';

// 3. Network info
final connectivity = await Connectivity().checkConnectivity();
// Returns: ConnectivityResult.wifi or .mobile

// 4. Display all statuses
// Backend: ✓ Online (45ms)
// Firebase Auth: ✓ Connected
// Firestore: ✓ Synced
// Chat API: ✓ Responding
// Network: WiFi (Strong signal)

// 5. User taps refresh
// All checks re-run
// Statuses updated
```



---

## 12. PROFILE SCREEN

**File**: `lib/screens/profile_screen.dart`

### Data Flow
```
ProfileScreen
  ├─ Load User Profile
  │   ├─ authUserProvider (current Firebase user)
  │   ├─ Fetch: displayName, email, photoURL
  │   └─ userSettingsProvider (user preferences)
  │
  ├─ Display Sections
  │   ├─ Avatar
  │   │   ├─ Current: photoURL or initials
  │   │   ├─ "Change Avatar" button
  │   │   └─ Opens: Image picker or camera
  │   │
  │   ├─ User Info
  │   │   ├─ Display Name (editable)
  │   │   ├─ Email (read-only)
  │   │   ├─ Account Created: createdAt
  │   │   └─ Last Login: lastSignInTime
  │   │
  │   ├─ Statistics
  │   │   ├─ Total Tasks Created
  │   │   ├─ Tasks Completed
  │   │   ├─ Chat Sessions
  │   │   └─ Focus Hours
  │   │
  │   ├─ Character Style
  │   │   ├─ Current: userSettings.characterStyle
  │   │   ├─ Options: tech, street, space, mythic
  │   │   └─ Preview of selected style
  │   │
  │   └─ Account Actions
  │       ├─ "Change Password" → Password reset flow
  │       ├─ "Sign Out" → AuthService.signOut()
  │       └─ "Delete Account" → Confirmation dialog
  │
  ├─ Edit Display Name
  │   ├─ User edits name
  │   ├─ User.updateDisplayName(newName)
  │   ├─ Firebase Auth updated
  │   └─ authUserProvider stream emits
  │
  ├─ Upload Avatar
  │   ├─ User selects image
  │   ├─ Upload to Firebase Storage
  │   ├─ Get download URL
  │   ├─ User.updatePhotoURL(url)
  │   └─ authUserProvider stream emits
  │
  ├─ Change Character Style
  │   ├─ User selects style
  │   ├─ userSettingsProvider.notifier.update()
  │   ├─ Saved to: UserSettingsStore
  │   ├─ Synced to: Firestore
  │   └─ UI theme updates
  │
  └─ Sign Out
      ├─ AuthService.signOut()
      ├─ FirebaseAuth.signOut()
      ├─ Clear local storage
      ├─ tokenProvider.notifier.state = null
      └─ Navigate to LoginScreen
```

### Data Generated
- **Updated Profile**: displayName, photoURL
- **Character Style**: Selected theme preference
- **Statistics**: Aggregated from tasks and sessions

### Example
```dart
// ProfileScreen loads
// 1. Get current user
final user = await ref.watch(authUserProvider.future);
// User(
//   uid: 'user_123',
//   email: 'user@example.com',
//   displayName: 'John Doe',
//   photoURL: 'https://...',
//   metadata: UserMetadata(createdAt: '2025-01-01', lastSignInTime: '2025-12-22')
// )

// 2. Get user settings
final settings = await ref.watch(userSettingsProvider.future);
// UserSettings(characterStyle: 'tech', ...)

// 3. Get statistics
final stats = await ref.watch(userStatsProvider.future);
// { tasksCreated: 45, tasksCompleted: 32, chatSessions: 28, focusHours: 120 }

// 4. User changes display name to "Jane Doe"
await user?.updateDisplayName('Jane Doe');
// authUserProvider stream emits new user
// UI updates with new name

// 5. User uploads avatar
final imageFile = await imagePicker.pickImage();
final ref = FirebaseStorage.instance.ref('avatars/user_123.jpg');
await ref.putFile(imageFile);
final url = await ref.getDownloadURL();
await user?.updatePhotoURL(url);
// authUserProvider stream emits
// UI updates with new avatar

// 6. User changes character style to "space"
await ref.read(userSettingsProvider.notifier).update(
  characterStyle: 'space'
);
// Saved to UserSettingsStore
// Synced to Firestore
// App theme updates to space theme

// 7. User signs out
await ref.read(authServiceProvider).signOut();
// FirebaseAuth.signOut()
// tokenProvider cleared
// Navigate to LoginScreen
```

---

## 13. SETTINGS SCREEN

**File**: `lib/screens/settings_screen.dart`

### Data Flow
```
SettingsScreen
  ├─ Load Settings
  │   ├─ userSettingsProvider
  │   ├─ Fetch from: UserSettingsStore
  │   └─ Display all preferences
  │
  ├─ Settings Sections
  │   ├─ Voice Settings
  │   │   ├─ TTS Voice: Dropdown (male/female/neutral)
  │   │   ├─ TTS Quality: Dropdown (low/medium/high)
  │   │   ├─ STT Provider: Dropdown (device/cloud)
  │   │   └─ Voice Lock: Toggle (lock during session)
  │   │
  │   ├─ Pulse Visualization
  │   │   ├─ Speed: Slider (500-2000ms)
  │   │   ├─ Threshold: Slider (0-100%)
  │   │   ├─ Max Frequency: Slider (1.0-5.0)
  │   │   ├─ Base Color: Color picker
  │   │   └─ Alert Color: Color picker
  │   │
  │   ├─ Notification Preferences
  │   │   ├─ Task Reminders: Toggle
  │   │   ├─ Time Blindness Alerts: Toggle
  │   │   ├─ Energy Alerts: Toggle
  │   │   ├─ Decision Support: Toggle
  │   │   ├─ Body Doubling: Toggle
  │   │   └─ System Push: Toggle
  │   │
  │   ├─ Sync Settings
  │   │   ├─ Firestore Sync: Toggle
  │   │   ├─ Google Search: Toggle
  │   │   └─ Last Sync: timestamp
  │   │
  │   ├─ Localization
  │   │   ├─ Language: Dropdown
  │   │   ├─ Locale: Dropdown
  │   │   └─ Timezone: Auto-detected
  │   │
  │   └─ Advanced
  │       ├─ Debug Mode: Toggle
  │       ├─ Clear Cache: Button
  │       └─ Export Data: Button
  │
  ├─ Update Setting
  │   ├─ User changes setting
  │   ├─ userSettingsProvider.notifier.update()
  │   ├─ Saved to: UserSettingsStore (local)
  │   ├─ Synced to: Firestore (if enabled)
  │   └─ Dependent providers invalidated
  │
  └─ Advanced Actions
      ├─ Clear Cache
      │   ├─ Clear SharedPreferences
      │   ├─ Clear image cache
      │   └─ Show confirmation
      │
      └─ Export Data
          ├─ Collect all user data
          ├─ Generate JSON file
          ├─ Save to device storage
          └─ Show success message
```

### Data Generated
- **Updated Settings**: All preference changes
- **Sync Status**: Last sync timestamp
- **Exported Data**: JSON file with all user data

### Example
```dart
// SettingsScreen loads
// 1. Fetch current settings
final settings = await ref.watch(userSettingsProvider.future);
// UserSettings(
//   pulseSpeedMs: 900,
//   ttsVoice: 'female',
//   ttsQuality: 'high',
//   sttProvider: 'device',
//   taskRemindersEnabled: true,
//   firestoreSyncEnabled: true,
//   characterStyle: 'tech'
// )

// 2. User changes TTS voice to "male"
await ref.read(userSettingsProvider.notifier).update(
  ttsVoice: 'male'
);
// Saved to UserSettingsStore
// Synced to Firestore
// TtsService updated with new voice

// 3. User adjusts pulse speed to 1200ms
await ref.read(userSettingsProvider.notifier).update(
  pulseSpeedMs: 1200
);
// Pulse animation speed updates immediately

// 4. User enables "Energy Alerts"
await ref.read(userSettingsProvider.notifier).update(
  energyAlertsEnabled: true
);
// Notification system updated
// Will show alerts when energy drops below threshold

// 5. User disables "Firestore Sync"
await ref.read(userSettingsProvider.notifier).update(
  firestoreSyncEnabled: false
);
// Chat and settings will only use local storage
// No cloud sync until re-enabled

// 6. User clears cache
await SharedPreferences.getInstance().then((p) => p.clear());
// Local cache cleared
// Next load will fetch fresh data from backend

// 7. User exports data
final allData = {
//   "user": { ... },
//   "tasks": [ ... ],
//   "chat_sessions": [ ... ],
//   "settings": { ... },
//   "metrics": { ... }
// };
// Save to device storage as JSON
```



---

## 14. EXTERNAL BRAIN SCREEN

**File**: `lib/screens/external_brain_screen.dart`

### Data Flow
```
ExternalBrainScreen
  ├─ Load Notes
  │   ├─ externalBrainProvider
  │   ├─ Fetch from: Firestore or local storage
  │   ├─ GET /external-brain/notes
  │   └─ Returns: List of notes with metadata
  │
  ├─ Display Sections
  │   ├─ Notes List
  │   │   ├─ Title, preview, date
  │   │   ├─ Search/filter capability
  │   │   └─ Sort by: date, title, tags
  │   │
  │   ├─ Quick Capture Button
  │   │   ├─ Opens: QuickCaptureModal
  │   │   ├─ Voice or text input
  │   │   └─ Auto-save to external brain
  │   │
  │   └─ Note Detail View
  │       ├─ Full note content
  │       ├─ Tags
  │       ├─ Creation/edit dates
  │       ├─ Edit button
  │       └─ Delete button
  │
  ├─ Create Note
  │   ├─ User taps "New Note"
  │   ├─ Opens: Note editor
  │   ├─ User enters: Title, content, tags
  │   ├─ externalBrainProvider.notifier.createNote(note)
  │   ├─ POST /external-brain/notes
  │   └─ Note saved and displayed
  │
  ├─ Edit Note
  │   ├─ User taps note
  │   ├─ Opens: Note editor with content
  │   ├─ User modifies content
  │   ├─ externalBrainProvider.notifier.updateNote(note)
  │   ├─ PUT /external-brain/notes/{id}
  │   └─ Note updated
  │
  ├─ Delete Note
  │   ├─ User taps delete
  │   ├─ Confirmation dialog
  │   ├─ externalBrainProvider.notifier.deleteNote(noteId)
  │   ├─ DELETE /external-brain/notes/{id}
  │   └─ Note removed from list
  │
  ├─ Quick Capture (Voice)
  │   ├─ User taps voice button
  │   ├─ SpeechService.listen()
  │   ├─ Partial text displayed
  │   ├─ On speech end → auto-save
  │   ├─ POST /external-brain/notes (with voice transcription)
  │   └─ Note created
  │
  └─ Search/Filter
      ├─ User enters search query
      ├─ externalBrainSearchProvider (StateProvider)
      ├─ Filter notes by: title, content, tags
      └─ Real-time filtering
```

### Data Generated
- **Note Object**: { id, title, content, tags, createdAt, updatedAt }
- **Note List**: Array of notes with metadata
- **Search Results**: Filtered note list

### Example
```dart
// ExternalBrainScreen loads
// 1. Fetch all notes
final notes = await ref.watch(externalBrainProvider.future);
// [
//   {
//     id: 'note_1',
//     title: 'Project Ideas',
//     content: 'Idea 1: Build dashboard...',
//     tags: ['ideas', 'project'],
//     createdAt: '2025-12-20T10:00:00Z',
//     updatedAt: '2025-12-22T14:30:00Z'
//   },
//   { ... }
// ]

// 2. User creates new note
final note = ExternalBrainNote(
  title: 'Meeting Notes',
  content: 'Discussed Q1 roadmap...',
  tags: ['meeting', 'planning']
);
await ref.read(externalBrainProvider.notifier).createNote(note);
// POST /external-brain/notes
// { title, content, tags, createdAt: now }
// Returns: { id: 'note_xyz', ...note }

// 3. User searches for "project"
ref.read(externalBrainSearchProvider.notifier).state = 'project';
// Filtered: [{ id: 'note_1', title: 'Project Ideas', ... }]

// 4. User uses voice capture
// Taps voice button
// SpeechService.listen() starts
// User speaks: "Remember to review the budget proposal"
// Transcription: "Remember to review the budget proposal"
// Auto-save as note:
// POST /external-brain/notes
// { title: 'Voice Note', content: 'Remember to review the budget proposal', ... }

// 5. User edits note
final updatedNote = note.copyWith(
  content: 'Updated content...'
);
await ref.read(externalBrainProvider.notifier).updateNote(updatedNote);
// PUT /external-brain/notes/{id}
// externalBrainProvider invalidated
// UI refreshes with updated note

// 6. User deletes note
await ref.read(externalBrainProvider.notifier).deleteNote('note_1');
// DELETE /external-brain/notes/note_1
// externalBrainProvider invalidated
// Note removed from list
```

---

## 15. VOICE MODE SCREEN

**File**: `lib/screens/voice_mode_screen.dart`

### Data Flow
```
VoiceModeScreen
  ├─ Initialize Voice Mode
  │   ├─ SpeechService.initialize()
  │   ├─ TtsService.initialize()
  │   ├─ Check microphone permission
  │   └─ Start listening
  │
  ├─ User Speaks
  │   ├─ SpeechService.listen()
  │   ├─ Partial transcription updates
  │   ├─ Display: Real-time text
  │   ├─ Waveform animation
  │   └─ On speech end → send message
  │
  ├─ Send Message
  │   ├─ Transcribed text sent to chat
  │   ├─ ApiClient.chatRespond(message, sessionId)
  │   ├─ POST /chat/respond
  │   └─ Backend processes
  │
  ├─ Receive Response
  │   ├─ Assistant message received
  │   ├─ Display: Text on screen
  │   ├─ TtsService.speak(response)
  │   ├─ Audio plays automatically
  │   └─ Waveform animates during playback
  │
  ├─ Realtime Voice Mode (Gemini Live)
  │   ├─ RealtimeVoiceService.connect()
  │   ├─ WebSocket connection to Gemini Live
  │   ├─ Stream audio chunks
  │   ├─ Receive audio response chunks
  │   ├─ Play audio in real-time
  │   └─ Lower latency conversation
  │
  ├─ UI Elements
  │   ├─ Waveform visualization
  │   ├─ Transcription text (live)
  │   ├─ Response text
  │   ├─ Pause/Resume buttons
  │   ├─ Stop button
  │   └─ Settings button
  │
  └─ Exit Voice Mode
      ├─ User taps back/close
      ├─ SpeechService.stop()
      ├─ TtsService.stop()
      ├─ Close WebSocket (if realtime)
      └─ Return to ChatScreen
```

### Data Generated
- **Transcribed Text**: User's speech converted to text
- **Assistant Response**: Text response from backend
- **Audio Stream**: Real-time audio chunks (Gemini Live)

### Example
```dart
// VoiceModeScreen initializes
// 1. Initialize services
await speechService.initialize();
await ttsService.initialize();
await realtimeVoiceService.connect();

// 2. User speaks: "What are my tasks for today?"
// SpeechService.listen() captures audio
// Partial transcriptions:
// "What"
// "What are"
// "What are my"
// "What are my tasks"
// "What are my tasks for today?"

// 3. On speech end, send message
final transcription = 'What are my tasks for today?';
final response = await apiClient.chatRespond(
  message: transcription,
  sessionId: 'sess_abc123'
);

// 4. Backend response
// {
//   "response": "You have 3 tasks today: Review docs, Fix bug, Email client",
//   "metadata": { "model": "gemini-2.0-flash" }
// }

// 5. Display response and play audio
await ttsService.speak(response['response']);
// Audio plays: "You have 3 tasks today..."
// Waveform animates during playback

// 6. Realtime mode (Gemini Live)
// WebSocket connection established
// User speaks continuously
// Audio chunks streamed to Gemini Live
// Response audio chunks received and played immediately
// Lower latency, more natural conversation

// 7. User stops voice mode
await speechService.stop();
await ttsService.stop();
await realtimeVoiceService.disconnect();
// Return to ChatScreen
```



---

## 16. FOCUS SESSION SCREEN (Time Perception)

**File**: `lib/screens/focus_session_screen.dart` / `lib/screens/time_perception_screen.dart`

### Data Flow
```
FocusSessionScreen
  ├─ Initialize Session
  │   ├─ User selects: Duration (15/30/45/60 min)
  │   ├─ User selects: Task (optional)
  │   ├─ focusSessionProvider.notifier.startSession()
  │   ├─ POST /focus-sessions/start
  │   └─ Session ID generated
  │
  ├─ Session Running
  │   ├─ Timer countdown
  │   ├─ Pulse visualization (energy indicator)
  │   ├─ Current task display
  │   ├─ Distraction counter (optional)
  │   └─ Real-time metrics
  │
  ├─ Periodic Updates
  │   ├─ Every 5 minutes:
  │   │   ├─ Send checkpoint to backend
  │   │   ├─ POST /focus-sessions/{id}/checkpoint
  │   │   ├─ Include: elapsed time, energy level
  │   │   └─ Receive: encouragement message
  │   │
  │   └─ Energy tracking:
  │       ├─ Monitor user activity
  │       ├─ Update energy level
  │       └─ Adjust UI based on energy
  │
  ├─ Session End
  │   ├─ Timer reaches zero
  │   ├─ focusSessionProvider.notifier.endSession()
  │   ├─ POST /focus-sessions/{id}/end
  │   ├─ Include: total duration, distractions, energy
  │   └─ Show summary
  │
  ├─ Session Summary
  │   ├─ Total focus time
  │   ├─ Distractions count
  │   ├─ Energy change
  │   ├─ Task progress
  │   ├─ Achievements unlocked
  │   └─ Encouragement message
  │
  ├─ Pause/Resume
  │   ├─ User taps pause
  │   ├─ Timer paused
  │   ├─ POST /focus-sessions/{id}/pause
  │   ├─ User taps resume
  │   ├─ Timer resumes
  │   └─ POST /focus-sessions/{id}/resume
  │
  └─ Early Exit
      ├─ User taps stop
      ├─ Confirmation dialog
      ├─ focusSessionProvider.notifier.endSession()
      ├─ POST /focus-sessions/{id}/end (early)
      └─ Show partial summary
```

### Data Generated
- **Focus Session**: { id, duration, taskId, startTime, endTime, status }
- **Checkpoints**: { timestamp, elapsedTime, energyLevel, distractions }
- **Session Summary**: { totalTime, distractions, energyChange, achievements }

### Example
```dart
// FocusSessionScreen loads
// 1. User selects 30-minute session for "Review docs" task
final session = FocusSession(
  duration: Duration(minutes: 30),
  taskId: 'task_1',
  startTime: DateTime.now()
);

await ref.read(focusSessionProvider.notifier).startSession(session);
// POST /focus-sessions/start
// { duration: 1800, task_id: 'task_1', start_time: '2025-12-22T14:30:00Z' }
// Returns: { id: 'focus_xyz', ...session }

// 2. Session running
// Timer: 29:45, 29:30, 29:15, ...
// Pulse visualization shows energy level
// Display: "Reviewing docs - 29:45 remaining"

// 3. Every 5 minutes, send checkpoint
// At 25:00 mark:
await apiClient.post('/focus-sessions/focus_xyz/checkpoint', {
  'elapsed_time': 300,
  'energy_level': 72,
  'distractions': 0
});
// Response: { "message": "Great focus! Keep it up!" }

// 4. User gets distracted, taps distraction counter
// Distractions: 1
// Backend tracks this

// 5. Session ends (timer reaches 0:00)
await ref.read(focusSessionProvider.notifier).endSession();
// POST /focus-sessions/focus_xyz/end
// { total_duration: 1800, distractions: 2, energy_change: +5 }

// 6. Show summary
// Focus Time: 30 minutes
// Distractions: 2
// Energy: 72 → 77 (+5)
// Task Progress: 50% complete
// Achievement: "Focused Warrior" unlocked!
// Message: "Excellent focus session! You're on fire!"
```

---

## 17. NOTION SETTINGS SCREEN

**File**: `lib/screens/notion_settings_screen.dart`

### Data Flow
```
NotionSettingsScreen
  ├─ Load Notion Status
  │   ├─ notionAuthProvider
  │   ├─ Check: Is user authenticated with Notion?
  │   ├─ Fetch: Connected databases
  │   └─ Display: Connection status
  │
  ├─ Display Sections
  │   ├─ Connection Status
  │   │   ├─ Connected/Disconnected
  │   │   ├─ Last sync: timestamp
  │   │   └─ Sync status: In progress/Complete
  │   │
  │   ├─ Linked Databases
  │   │   ├─ List of connected Notion databases
  │   │   ├─ Database name, icon, last updated
  │   │   └─ Unlink button for each
  │   │
  │   ├─ Sync Settings
  │   │   ├─ Auto-sync: Toggle
  │   │   ├─ Sync frequency: Dropdown (hourly/daily)
  │   │   ├─ Sync direction: Dropdown (one-way/two-way)
  │   │   └─ Last sync: timestamp
  │   │
  │   └─ Actions
  │       ├─ "Connect Notion" button
  │       ├─ "Sync Now" button
  │       └─ "Disconnect" button
  │
  ├─ Connect Notion
  │   ├─ User taps "Connect Notion"
  │   ├─ NotionAuthService.startOAuthFlow()
  │   ├─ Opens: Notion OAuth login
  │   ├─ User authorizes app
  │   ├─ Notion returns: Authorization code
  │   ├─ Backend exchanges code for access token
  │   ├─ POST /notion/auth/callback
  │   ├─ Token stored securely
  │   └─ notionAuthProvider updated
  │
  ├─ Fetch Databases
  │   ├─ NotionService.getDatabases()
  │   ├─ GET /notion/databases
  │   ├─ Returns: List of user's Notion databases
  │   └─ Display in settings
  │
  ├─ Link Database
  │   ├─ User selects database
  │   ├─ NotionService.linkDatabase(databaseId)
  │   ├─ POST /notion/databases/{id}/link
  │   ├─ Configure sync settings
  │   └─ Start initial sync
  │
  ├─ Sync Now
  │   ├─ User taps "Sync Now"
  │   ├─ NotionService.syncNow()
  │   ├─ POST /notion/sync
  │   ├─ Fetch latest data from Notion
  │   ├─ Update local database
  │   ├─ Show progress indicator
  │   └─ Show completion message
  │
  └─ Disconnect
      ├─ User taps "Disconnect"
      ├─ Confirmation dialog
      ├─ NotionAuthService.disconnect()
      ├─ DELETE /notion/auth
      ├─ Clear stored token
      └─ notionAuthProvider updated
```

### Data Generated
- **Notion Auth Token**: OAuth access token (stored securely)
- **Linked Databases**: List of connected Notion databases
- **Sync Status**: Last sync time, sync progress

### Example
```dart
// NotionSettingsScreen loads
// 1. Check Notion connection status
final notionAuth = await ref.watch(notionAuthProvider.future);
// { connected: true, lastSync: '2025-12-22T10:00:00Z' }

// 2. Fetch linked databases
final databases = await notionService.getDatabases();
// [
//   { id: 'db_1', name: 'Tasks', icon: '✓', lastUpdated: '2025-12-22T10:00:00Z' },
//   { id: 'db_2', name: 'Notes', icon: '📝', lastUpdated: '2025-12-21T15:30:00Z' }
// ]

// 3. User taps "Connect Notion"
await notionAuthService.startOAuthFlow();
// Opens Notion OAuth login
// User logs in and authorizes
// Notion redirects to: oauth_redirect_server.py
// Backend exchanges code for token
// POST /notion/auth/callback
// { code: 'auth_code_xyz' }
// Returns: { access_token: 'token_abc123', ... }
// Token stored in SecureStorage

// 4. User selects database to link
await notionService.linkDatabase('db_1');
// POST /notion/databases/db_1/link
// { access_token: 'token_abc123' }
// Initial sync starts

// 5. User taps "Sync Now"
await notionService.syncNow();
// POST /notion/sync
// Fetches latest data from Notion
// Updates local database
// Progress: 0% → 50% → 100%
// Message: "Sync complete! 45 items updated"

// 6. User disconnects
await notionAuthService.disconnect();
// DELETE /notion/auth
// Token cleared from SecureStorage
// notionAuthProvider updated
// UI shows "Not connected"
```



---

## 18. NOTION LIBRARY SCREEN

**File**: `lib/screens/notion_library_screen.dart`

### Data Flow
```
NotionLibraryScreen
  ├─ Load Notion Data
  │   ├─ notionLibraryProvider
  │   ├─ Fetch: All linked Notion databases
  │   ├─ GET /notion/databases
  │   └─ Display: Database list with items
  │
  ├─ Display Sections
  │   ├─ Database Selector
  │   │   ├─ Dropdown of linked databases
  │   │   ├─ User selects database
  │   │   └─ notionSelectedDatabaseProvider updated
  │   │
  │   ├─ Items List
  │   │   ├─ Display items from selected database
  │   │   ├─ Show: Title, properties, last updated
  │   │   ├─ Search/filter capability
  │   │   └─ Pagination (20 items per page)
  │   │
  │   ├─ Item Detail
  │   │   ├─ User taps item
  │   │   ├─ Show: Full item details
  │   │   ├─ Properties: All database fields
  │   │   ├─ Relations: Linked items
  │   │   └─ Edit button
  │   │
  │   └─ Actions
  │       ├─ "Create Item" button
  │       ├─ "Refresh" button
  │       └─ "Search" input
  │
  ├─ Fetch Database Items
  │   ├─ User selects database
  │   ├─ NotionService.getDatabaseItems(databaseId)
  │   ├─ GET /notion/databases/{id}/items
  │   ├─ Returns: Paginated list of items
  │   └─ Display in list
  │
  ├─ Search Items
  │   ├─ User enters search query
  │   ├─ notionSearchQueryProvider (StateProvider)
  │   ├─ Filter items by: title, properties
  │   └─ Real-time filtering
  │
  ├─ View Item Details
  │   ├─ User taps item
  │   ├─ NotionService.getItemDetails(itemId)
  │   ├─ GET /notion/items/{id}
  │   ├─ Returns: Full item with all properties
  │   └─ Display in detail view
  │
  ├─ Create Item
  │   ├─ User taps "Create Item"
  │   ├─ Opens: Item creation form
  │   ├─ User fills: Title, properties
  │   ├─ NotionService.createItem(databaseId, item)
  │   ├─ POST /notion/databases/{id}/items
  │   ├─ Item created in Notion
  │   └─ notionLibraryProvider invalidated
  │
  ├─ Edit Item
  │   ├─ User taps "Edit"
  │   ├─ Opens: Item editor
  │   ├─ User modifies: Properties
  │   ├─ NotionService.updateItem(itemId, updates)
  │   ├─ PUT /notion/items/{id}
  │   ├─ Item updated in Notion
  │   └─ notionLibraryProvider invalidated
  │
  └─ Pagination
      ├─ User scrolls to bottom
      ├─ Load next page
      ├─ GET /notion/databases/{id}/items?page=2
      ├─ Append items to list
      └─ Continue scrolling
```

### Data Generated
- **Database Items**: Array of items from selected database
- **Item Details**: Full item with all properties
- **Search Results**: Filtered item list

### Example
```dart
// NotionLibraryScreen loads
// 1. Fetch linked databases
final databases = await notionService.getDatabases();
// [
//   { id: 'db_1', name: 'Tasks', icon: '✓' },
//   { id: 'db_2', name: 'Notes', icon: '📝' }
// ]

// 2. User selects "Tasks" database
ref.read(notionSelectedDatabaseProvider.notifier).state = 'db_1';

// 3. Fetch items from database
final items = await notionService.getDatabaseItems('db_1');
// [
//   {
//     id: 'item_1',
//     title: 'Review Q1 Budget',
//     properties: {
//       'Status': 'In Progress',
//       'Priority': 'High',
//       'Due Date': '2025-12-31'
//     },
//     lastUpdated: '2025-12-22T10:00:00Z'
//   },
//   { ... }
// ]

// 4. User searches for "budget"
ref.read(notionSearchQueryProvider.notifier).state = 'budget';
// Filtered: [{ id: 'item_1', title: 'Review Q1 Budget', ... }]

// 5. User taps item to view details
final itemDetails = await notionService.getItemDetails('item_1');
// {
//   id: 'item_1',
//   title: 'Review Q1 Budget',
//   properties: {
//     'Status': 'In Progress',
//     'Priority': 'High',
//     'Due Date': '2025-12-31',
//     'Assigned To': 'John Doe',
//     'Description': 'Review and approve Q1 budget proposal'
//   },
//   relations: [
//     { type: 'related_to', items: ['item_5', 'item_8'] }
//   ]
// }

// 6. User creates new item
final newItem = {
//   'title': 'Plan Q2 Strategy',
//   'properties': {
//     'Status': 'Not Started',
//     'Priority': 'Medium',
//     'Due Date': '2026-03-31'
//   }
// };
await notionService.createItem('db_1', newItem);
// POST /notion/databases/db_1/items
// Item created in Notion
// notionLibraryProvider invalidated
// New item appears in list

// 7. User edits item
final updates = {
//   'Status': 'Completed',
//   'Priority': 'Low'
// };
await notionService.updateItem('item_1', updates);
// PUT /notion/items/item_1
// Item updated in Notion
// notionLibraryProvider invalidated
// UI refreshes with updated item
```

---

## 19. QUICK CAPTURE MODAL

**File**: `lib/screens/quick_capture_modal.dart`

### Data Flow
```
QuickCaptureModal
  ├─ Initialize
  │   ├─ User taps quick capture button
  │   ├─ Modal opens (bottom sheet)
  │   ├─ Show: Voice and text input options
  │   └─ Default: Voice mode
  │
  ├─ Voice Capture
  │   ├─ SpeechService.listen()
  │   ├─ User speaks
  │   ├─ Partial transcription displayed
  │   ├─ On speech end:
  │   │   ├─ Transcription complete
  │   │   ├─ Show: Transcribed text
  │   │   ├─ Show: "Save" and "Discard" buttons
  │   │   └─ Allow editing before save
  │   │
  │   └─ Save Voice Capture
  │       ├─ Create note/task from transcription
  │       ├─ Determine: Is it a task or note?
  │       ├─ If task: POST /tasks/
  │       ├─ If note: POST /external-brain/notes
  │       └─ Close modal
  │
  ├─ Text Capture
  │   ├─ User taps text input
  │   ├─ Opens: Text editor
  │   ├─ User types content
  │   ├─ Show: "Save" and "Discard" buttons
  │   └─ Save Text Capture
  │       ├─ Create note/task from text
  │       ├─ Determine: Is it a task or note?
  │       ├─ If task: POST /tasks/
  │       ├─ If note: POST /external-brain/notes
  │       └─ Close modal
  │
  ├─ AI Classification
  │   ├─ Send captured text to backend
  │   ├─ POST /capture/classify
  │   ├─ Backend uses AI to determine: task or note?
  │   ├─ Returns: { type: 'task'|'note', confidence: 0.95 }
  │   └─ Route to appropriate endpoint
  │
  └─ Close Modal
      ├─ User taps close/back
      ├─ Discard unsaved content
      └─ Return to previous screen
```

### Data Generated
- **Captured Text**: Transcribed or typed content
- **Classification**: Task or note determination
- **Created Item**: Task or note object with metadata

### Example
```dart
// User taps quick capture button
// QuickCaptureModal opens

// 1. Voice capture
// User taps voice button
// SpeechService.listen() starts
// User speaks: "Remember to call the client about the proposal"
// Transcription: "Remember to call the client about the proposal"

// 2. AI classification
await apiClient.post('/capture/classify', {
  'text': 'Remember to call the client about the proposal'
});
// Response: { type: 'task', confidence: 0.92 }

// 3. Create task
final task = Task(
  title: 'Call the client about the proposal',
  description: 'From voice capture',
  priority: 'medium',
  status: 'pending'
);
await taskService.createTask(task);
// POST /tasks/
// Task created

// 4. Close modal
// Modal closes
// Return to previous screen
// Task appears in task list

// Alternative: Text capture
// User taps text input
// Types: "Project ideas: dashboard redesign, mobile app"
// AI classification: { type: 'note', confidence: 0.88 }
// Create note:
final note = ExternalBrainNote(
  title: 'Project Ideas',
  content: 'dashboard redesign, mobile app'
);
await externalBrainService.createNote(note);
// POST /external-brain/notes
// Note created
// Modal closes
```

---

## 20. HEALTH SCREEN

**File**: `lib/screens/health_screen.dart`

### Data Flow
```
HealthScreen
  ├─ System Health Check
  │   ├─ ApiClient.health()
  │   ├─ GET /health
  │   └─ Returns: System status
  │
  ├─ Display Sections
  │   ├─ Backend Status
  │   │   ├─ Status: Online/Offline
  │   │   ├─ Response time
  │   │   └─ Last check
  │   │
  │   ├─ Database Status
  │   │   ├─ Firestore: Connected/Disconnected
  │   │   ├─ Sync status
  │   │   └─ Last sync
  │   │
  │   ├─ API Endpoints
  │   │   ├─ Chat API
  │   │   ├─ Tasks API
  │   │   ├─ Metrics API
  │   │   └─ Calendar API
  │   │
  │   ├─ External Services
  │   │   ├─ Vertex AI
  │   │   ├─ Google Calendar
  │   │   ├─ Notion API
  │   │   └─ Speech Services
  │   │
  │   └─ Device Info
  │       ├─ OS version
  │       ├─ App version
  │       ├─ Storage available
  │       └─ Memory usage
  │
  ├─ Refresh Button
  │   ├─ Re-run all checks
  │   └─ Update all statuses
  │
  └─ Detailed Logs
      ├─ Recent errors
      ├─ Warnings
      └─ Info messages
```

### Data Generated
- **Health Status**: { status, timestamp, responseTime }
- **Service Statuses**: Array of service checks
- **Device Info**: OS, app version, storage, memory

### Example
```dart
// HealthScreen loads
// 1. Run health check
final health = await apiClient.health();
// {
//   "status": "healthy",
//   "uptime": 86400,
//   "services": {
//     "auth": "ok",
//     "firestore": "ok",
//     "vertex_ai": "ok",
//     "calendar": "ok"
//   },
//   "response_time_ms": 45
// }

// 2. Check Firebase status
final firebaseStatus = FirebaseAuth.instance.currentUser != null ? 'connected' : 'disconnected';

// 3. Check device info
final deviceInfo = await DeviceInfoPlugin().androidInfo;
// { osVersion: '14', appVersion: '1.0.0', ... }

// 4. Display all statuses
// Backend: ✓ Online (45ms)
// Firebase: ✓ Connected
// Firestore: ✓ Synced
// Chat API: ✓ Responding
// Vertex AI: ✓ Available
// Device: Android 14, App v1.0.0
```



---

## 21. NOTIFICATION SETTINGS SCREEN

**File**: `lib/screens/notification_settings_screen.dart`

### Data Flow
```
NotificationSettingsScreen
  ├─ Load Notification Preferences
  │   ├─ userSettingsProvider
  │   ├─ Fetch: All notification toggles
  │   └─ Display: Current preferences
  │
  ├─ Display Sections
  │   ├─ Task Reminders
  │   │   ├─ Toggle: Enable/Disable
  │   │   ├─ Time: Select reminder time
  │   │   └─ Frequency: Daily/Weekly
  │   │
  │   ├─ Time Blindness Alerts
  │   │   ├─ Toggle: Enable/Disable
  │   │   ├─ Interval: Every 30/60/90 minutes
  │   │   └─ Message: Customizable
  │   │
  │   ├─ Energy Alerts
  │   │   ├─ Toggle: Enable/Disable
  │   │   ├─ Threshold: When energy drops below X%
  │   │   └─ Action: Suggest break/task
  │   │
  │   ├─ Decision Support
  │   │   ├─ Toggle: Enable/Disable
  │   │   ├─ Trigger: When facing decision
  │   │   └─ Format: Quick tips/detailed guide
  │   │
  │   ├─ Body Doubling
  │   │   ├─ Toggle: Enable/Disable
  │   │   ├─ Frequency: Check-in interval
  │   │   └─ Type: Text/Voice
  │   │
  │   └─ System Push Notifications
  │       ├─ Toggle: Enable/Disable
  │       ├─ Sound: On/Off
  │       └─ Vibration: On/Off
  │
  ├─ Update Preference
  │   ├─ User toggles setting
  │   ├─ userSettingsProvider.notifier.update()
  │   ├─ Saved to: UserSettingsStore
  │   ├─ Synced to: Firestore
  │   └─ Notification system updated
  │
  └─ Test Notification
      ├─ User taps "Send Test"
      ├─ NotificationService.sendTest()
      ├─ Sends sample notification
      └─ User sees preview
```

### Data Generated
- **Updated Preferences**: All notification settings
- **Notification Rules**: Triggers and conditions

### Example
```dart
// NotificationSettingsScreen loads
// 1. Fetch current preferences
final settings = await ref.watch(userSettingsProvider.future);
// UserSettings(
//   taskRemindersEnabled: true,
//   timeBlindnessEnabled: true,
//   energyAlertsEnabled: false,
//   decisionSupportEnabled: true,
//   bodyDoublingEnabled: false,
//   systemPushEnabled: true
// )

// 2. User enables "Energy Alerts"
await ref.read(userSettingsProvider.notifier).update(
  energyAlertsEnabled: true
);
// Saved to UserSettingsStore
// Synced to Firestore
// Notification system updated

// 3. User sets energy alert threshold to 40%
await ref.read(userSettingsProvider.notifier).update(
  energyAlertThreshold: 40
);
// When energy drops below 40%, notification sent

// 4. User enables "Body Doubling" with 30-minute check-ins
await ref.read(userSettingsProvider.notifier).update(
  bodyDoublingEnabled: true,
  bodyDoublingInterval: 30
);
// Every 30 minutes: "How's your focus? Keep going!"

// 5. User sends test notification
await notificationService.sendTest('Task Reminder');
// Sample notification appears on device
// User sees: "This is what your task reminders look like"
```

---

## 22. TASK FLOW AGENT SCREEN

**File**: `lib/screens/task_flow_agent_screen.dart`

### Data Flow
```
TaskFlowAgentScreen
  ├─ Initialize with Task
  │   ├─ Receive: taskId from navigation
  │   ├─ Fetch: Task details
  │   ├─ GET /tasks/{id}
  │   └─ Display: Task information
  │
  ├─ AI Task Breakdown
  │   ├─ User taps "Break Down Task"
  │   ├─ Send task to backend
  │   ├─ POST /tasks/{id}/breakdown
  │   ├─ Backend uses AI to generate subtasks
  │   ├─ Returns: { subtasks: [...], reasoning: "..." }
  │   └─ Display: Subtask list
  │
  ├─ Display Sections
  │   ├─ Main Task
  │   │   ├─ Title, description
  │   │   ├─ Priority, effort, due date
  │   │   └─ Status
  │   │
  │   ├─ Subtasks
  │   │   ├─ List of generated subtasks
  │   │   ├─ Checkbox to mark complete
  │   │   ├─ Effort estimate for each
  │   │   └─ Suggested order
  │   │
  │   ├─ AI Guidance
  │   │   ├─ Step-by-step instructions
  │   │   ├─ Tips and best practices
  │   │   ├─ Estimated time for each step
  │   │   └─ Common pitfalls to avoid
  │   │
  │   └─ Progress Tracking
  │       ├─ Overall progress bar
  │       ├─ Subtasks completed: X/Y
  │       ├─ Time spent
  │       └─ Estimated time remaining
  │
  ├─ Create Subtasks
  │   ├─ User accepts breakdown
  │   ├─ For each subtask:
  │   │   ├─ Create Task object
  │   │   ├─ Set parent task ID
  │   │   ├─ tasksProvider.notifier.createTask()
  │   │   ├─ POST /tasks/
  │   │   └─ Subtask created
  │   │
  │   └─ tasksProvider invalidated
  │       └─ Task list updated
  │
  ├─ Complete Subtask
  │   ├─ User checks subtask
  │   ├─ tasksProvider.notifier.updateTask()
  │   ├─ PUT /tasks/{id}
  │   ├─ Set status: 'completed'
  │   ├─ Progress bar updates
  │   └─ tasksProvider invalidated
  │
  ├─ Get Next Step
  │   ├─ User taps "What's Next?"
  │   ├─ POST /tasks/{id}/next-step
  │   ├─ Backend analyzes progress
  │   ├─ Returns: { nextStep: "...", reasoning: "..." }
  │   └─ Display: Recommended next action
  │
  └─ Complete Task
      ├─ All subtasks completed
      ├─ User taps "Mark Complete"
      ├─ tasksProvider.notifier.updateTask()
      ├─ PUT /tasks/{id}
      ├─ Set status: 'completed'
      ├─ Show: Celebration message
      └─ Return to task list
```

### Data Generated
- **Subtasks**: Array of generated subtasks
- **Breakdown Reasoning**: Explanation of breakdown
- **Progress**: Completion percentage
- **Next Step**: Recommended action

### Example
```dart
// TaskFlowAgentScreen loads with task
// 1. Fetch task details
final task = await taskService.getTask('task_1');
// {
//   id: 'task_1',
//   title: 'Build user dashboard',
//   description: 'Create a dashboard showing user metrics',
//   priority: 'high',
//   effort: 'high',
//   dueDate: '2025-12-31'
// }

// 2. User taps "Break Down Task"
final breakdown = await apiClient.post('/tasks/task_1/breakdown', {});
// Response:
// {
//   "subtasks": [
//     { title: 'Design wireframes', effort: 'low', order: 1 },
//     { title: 'Set up database schema', effort: 'medium', order: 2 },
//     { title: 'Create API endpoints', effort: 'high', order: 3 },
//     { title: 'Build UI components', effort: 'high', order: 4 },
//     { title: 'Integrate with backend', effort: 'medium', order: 5 },
//     { title: 'Test and debug', effort: 'medium', order: 6 }
//   ],
//   "reasoning": "Breaking down into design, backend, frontend, and testing phases"
// }

// 3. Display subtasks
// Progress: 0/6 (0%)
// Subtasks:
// ☐ Design wireframes (Low effort)
// ☐ Set up database schema (Medium effort)
// ☐ Create API endpoints (High effort)
// ☐ Build UI components (High effort)
// ☐ Integrate with backend (Medium effort)
// ☐ Test and debug (Medium effort)

// 4. User creates subtasks
for (var subtask in breakdown['subtasks']) {
  final newTask = Task(
    title: subtask['title'],
    effort: subtask['effort'],
    parentTaskId: 'task_1',
    status: 'pending'
  );
  await taskService.createTask(newTask);
}
// 6 subtasks created

// 5. User completes first subtask
await taskService.updateTask(
  Task(id: 'subtask_1', status: 'completed')
);
// Progress: 1/6 (17%)

// 6. User taps "What's Next?"
final nextStep = await apiClient.post('/tasks/task_1/next-step', {});
// Response:
// {
//   "nextStep": "Set up database schema for storing user metrics",
//   "reasoning": "Wireframes are done, now build the backend foundation",
//   "estimatedTime": "2 hours"
// }

// 7. All subtasks completed
// Progress: 6/6 (100%)
// Show: "🎉 Task Complete! Great work!"
// Return to task list
```

---

## COMPLETE DATA FLOW SUMMARY

### Authentication Flow
```
App Start
  ↓
SplashScreen (checks auth)
  ↓
[Authenticated] → MainScreen
[Not Authenticated] → LoginScreen/SignupScreen
```

### Main Navigation Flow
```
MainScreen (6-tab hub)
  ├─ Tab 0: Dashboard (home, energy, tasks)
  ├─ Tab 1: Metrics (analytics)
  ├─ Tab 2: Observability (system health)
  ├─ Tab 3: Profile (user info)
  ├─ Tab 4: External Brain (notes)
  └─ Tab 5: Settings (preferences)
```

### Data Persistence Strategy
```
Local Storage (SharedPreferences)
  ├─ Chat sessions and messages
  ├─ User settings
  ├─ Cache data
  └─ Offline capability

Secure Storage (FlutterSecureStorage)
  ├─ Auth tokens
  ├─ API keys
  ├─ Notion access tokens
  └─ Sensitive credentials

Cloud Storage (Firestore)
  ├─ User profile
  ├─ Chat history (sync)
  ├─ Settings (sync)
  └─ Metrics data

Firebase Storage
  └─ User avatars and media
```

### API Communication Pattern
```
UI Action
  ↓
Provider/Service method called
  ↓
ApiClient.method() (with auth token)
  ↓
POST/GET/PUT/DELETE to backend
  ↓
Backend processes (AI, database, etc.)
  ↓
Response returned
  ↓
Provider invalidated (if needed)
  ↓
UI rebuilds with new data
```

### State Management Pattern (Riverpod)
```
Providers (read-only data)
  ├─ FutureProvider (async data)
  ├─ StreamProvider (real-time data)
  └─ Provider (computed data)

StateProviders (mutable state)
  ├─ Simple state (string, int, bool)
  └─ Navigation state

StateNotifierProviders (complex state)
  ├─ TasksNotifier (task list management)
  ├─ ChatStoreNotifier (chat management)
  └─ UserSettingsNotifier (settings management)
```

---

## KEY TAKEAWAYS

1. **Dual-Write Pattern**: Data written to both local storage and cloud for offline capability
2. **Real-time Sync**: Firestore listeners keep data synchronized across devices
3. **AI Integration**: Vertex AI used for task prioritization, breakdown, and chat responses
4. **Voice-First**: Multiple voice features (STT, TTS, realtime voice mode)
5. **Modular Architecture**: Each screen has clear data flow and dependencies
6. **Error Handling**: Retry logic, timeout handling, graceful degradation
7. **Accessibility**: Timezone handling, locale support, motion preferences
8. **Security**: Secure token storage, auth token injection, permission handling

