# Supabase Integration Steps

## ✅ Dev Login Added
- Added "🔧 Dev Login (Skip Auth)" button to bypass authentication during development
- Fixed authentication flow to properly handle real Supabase auth
- Added loading states and error handling to login UI

## Step 1: Create Database Tables
1. Go to your Supabase dashboard: https://fjswkvgochsdmcqeaexc.supabase.co
2. Navigate to SQL Editor
3. Copy and paste the contents of `database_setup.sql`
4. Click "Run" to create all tables and policies

## Step 2: Add Supabase Package to Xcode
1. Open `medium2quiz.xcodeproj` in Xcode
2. Go to File → Add Package Dependencies
3. Enter URL: `https://github.com/supabase/supabase-swift.git`
4. Select "Up to Next Major Version" starting from 2.0.0
5. Add the package to your main target

## Step 3: Add .env File to Xcode Bundle
1. In Xcode, right-click on the project root
2. Select "Add Files to 'medium2quiz'"
3. Select the `.env` file (make sure "Add to target" is checked)
4. Ensure the file appears in the project navigator

## Step 4: Deploy Edge Function (Optional)
If you want to test content processing:
```bash
# Install Supabase CLI if not installed
npm install -g supabase

# Initialize Supabase in your project
supabase init

# Link to your project
supabase link --project-ref fjswkvgochsdmcqeaexc

# Deploy the edge function
supabase functions deploy process-content
```

## Step 5: Test the Integration
1. Build and run the app
2. Use "🔧 Dev Login" to skip authentication during development
3. Or test real auth with email/password signup

## Files Created/Modified:
- ✅ `.env` - Environment variables (your keys)
- ✅ `EnvironmentConfig.swift` - Config reader
- ✅ `database_setup.sql` - Complete database schema
- ✅ `SupabaseService.swift` - API service layer
- ✅ `AppViewModel.swift` - Updated with Supabase integration
- ✅ `OnboardingView.swift` - Added dev login option
- ✅ `supabase/functions/process-content/index.ts` - Edge function

## Next Development Steps:
1. Test basic authentication flow
2. Test article loading/saving
3. Test topic selection in explore mode
4. Test custom source addition
5. Test quiz card generation

The backend is now fully integrated and ready for development!