# Task App - Organized File Structure

## 📁 File Organization

Your Flutter app has been broken down into logical, related chunks to make Cursor more stable and your code easier to maintain:

### **`lib/main.dart`** (Main App Setup)
- App initialization and Firebase setup
- Provider configuration
- Route definitions
- Main app widget

### **`lib/models/task.dart`** (Data Models)
- Task class definition
- Data conversion methods (toMap, fromMap)
- copyWith method for updates

### **`lib/providers/`** (State Management)
- **`auth_provider.dart`** - User authentication (login, signup, logout)
- **`task_provider.dart`** - Task operations (add, edit, delete, toggle)

### **`lib/screens/`** (All Screens)
- **`login_screen.dart`** - User login
- **`signup_screen.dart`** - User registration
- **`task_screens.dart`** - Contains all task-related screens:
  - HomeScreen (main task list)
  - AddTaskScreen (create new tasks)
  - EditTaskScreen (modify existing tasks)
- **`other_screens.dart** - Contains:
  - CalendarScreen (calendar view of tasks)
  - ProfileScreen (user profile and settings)

## 🎯 Benefits of This Structure

1. **Cursor Stability** - Smaller files are easier for AI to process
2. **Logical Grouping** - Related functionality is kept together
3. **Easier Maintenance** - Find and fix issues faster
4. **Better Organization** - Clear separation of concerns
5. **Reusability** - Components can be imported where needed

## 🚀 How to Use

- **Main app logic** → `main.dart`
- **User authentication** → `providers/auth_provider.dart`
- **Task management** → `providers/task_provider.dart`
- **Task screens** → `screens/task_screens.dart`
- **Calendar & Profile** → `screens/other_screens.dart`

## 📱 Your App Features

- ✅ User authentication (login/signup)
- ✅ Create, edit, delete tasks
- ✅ Mark tasks as complete
- ✅ Calendar view of tasks
- ✅ User profile management
- ✅ Firebase backend integration

The app should now be much more stable in Cursor while maintaining all the same functionality!
