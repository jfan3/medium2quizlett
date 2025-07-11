# Supabase Setup Instructions

## Step 1: Add Supabase Package to Xcode

**Option A: Using Xcode UI (Recommended)**
1. Open `medium2quiz.xcodeproj` in Xcode
2. In Xcode, go to **File → Add Package Dependencies**
3. Enter this URL: `https://github.com/supabase/supabase-swift.git`
4. Click **Add Package**
5. Select version **2.0.0 or higher**
6. Choose **Supabase** from the package products
7. Click **Add Package**

**Option B: Using Package.swift (Alternative)**
If using a Swift Package Manager project, add this to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "Supabase", package: "supabase-swift")
        ]
    )
]
```

## Step 2: Add .env File to Xcode Bundle

1. In Xcode Project Navigator, right-click on the **medium2quiz** folder
2. Select **Add Files to "medium2quiz"**
3. Navigate to and select the `.env` file
4. Make sure **"Add to target"** is checked for **medium2quiz**
5. Click **Add**

## Step 3: Create Database Tables

1. Go to your Supabase dashboard: https://fjswkvgochsdmcqeaexc.supabase.co
2. Navigate to **SQL Editor**
3. Copy the entire contents of `database_setup.sql`
4. Paste into the SQL Editor
5. Click **Run** to create all tables and policies

## Step 4: Test the Integration

1. Build the project in Xcode (⌘+B)
2. If successful, run the app (⌘+R)
3. Go through onboarding and use the **"🔧 Dev Login (Skip Auth)"** button
4. You should reach the main app interface

## Step 5: Deploy Edge Function (Optional)

Only needed if you want to test content processing:

```bash
# Install Supabase CLI (if not installed)
npm install -g supabase

# Navigate to your project directory
cd /Users/jfan/Documents/models/medium2quizlett/medium2quiz

# Initialize Supabase (if not already done)
supabase init

# Link to your project
supabase link --project-ref fjswkvgochsdmcqeaexc

# Deploy the edge function
supabase functions deploy process-content
```

## Troubleshooting

**"No such module 'Supabase'" Error:**
- Make sure you've added the package dependency in Xcode
- Clean build folder (Product → Clean Build Folder)
- Restart Xcode

**"Cannot find 'EnvironmentConfig'" Error:**
- Make sure the `.env` file is added to the Xcode target
- Check that `EnvironmentConfig.swift` is in the project

**Database Connection Issues:**
- Verify your Supabase URL and keys in the `.env` file
- Check that the database tables were created successfully

## Files Structure After Setup

```
medium2quiz/
├── .env                          # Environment variables
├── database_setup.sql            # Database schema
├── medium2quiz/
│   ├── Config/
│   │   └── EnvironmentConfig.swift
│   ├── Services/
│   │   └── SupabaseService.swift
│   └── ViewModels/
│       └── AppViewModel.swift    # Updated with Supabase
└── supabase/
    └── functions/
        └── process-content/
            └── index.ts
```

The app now supports both:
- **Real authentication** with Supabase (email/password)
- **Dev login** for development (orange button)

Once the package is added, the app will compile and run successfully!