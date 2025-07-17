# Study Functionality Analysis & Implementation Plan

## Current Issues Identified

### 1. Wrong Topics in RSS Feed Setup
**Problem**: The RSS filtering logic uses `contains()` which is too broad, causing articles from unrelated topics to be included.

**Current Logic**:
```swift
if sourceTopic.contains(selectedTopic) || selectedTopic.contains(sourceTopic)
```

**Fix**: Use exact string matching for topic filtering.

### 2. Study Modes Not Working
**Problem**: All four study modes (Smart Study, Review Starred, Quick Test, New Cards) show "Card 1 of 0" indicating no flashcards are loaded.

**Root Cause**: The flashcards are being saved to the `quiz_cards` table, but the study functionality is trying to load from `user_quiz_performance` table which requires user-specific performance data.

## Implementation Plan

### Phase 1: Fix RSS Topic Filtering (High Priority)
1. **Update RSS filtering logic** to use exact topic matching
2. **Add topic normalization** to handle case variations
3. **Test with "Causal Inference"** to ensure only relevant sources are matched

### Phase 2: Fix Study Functionality (High Priority)
1. **Create user_quiz_performance records** when flashcards are first accessed
2. **Update StudyViewImproved** to properly load flashcards for each mode:
   - **Smart Study**: Mix of new, due, and learning cards
   - **Review Starred**: Only cards marked as starred in user_quiz_performance
   - **Quick Test**: Random selection of cards for quick review
   - **New Cards**: Cards never studied before (no user_quiz_performance record)

### Phase 3: Flashcard Access (Medium Priority)
1. **Add flashcard browsing** in Manage tab
2. **Enable flashcard search** by article title or content
3. **Add bulk actions** (star/unstar, mark as mastered)

### Phase 4: Study Session Improvements (Medium Priority)
1. **Implement spaced repetition** algorithm
2. **Track study statistics** properly
3. **Add progress persistence** across sessions

## Detailed Implementation Steps

### Step 1: Fix RSS Topic Filtering
- Location: `medium2quiz/Services/RSSService.swift` line ~150
- Change broad `contains()` to exact matching
- Add debug logging for topic matching

### Step 2: Initialize User Performance Records
- Create function to automatically create `user_quiz_performance` records when quiz_cards are accessed
- Location: `medium2quiz/Services/SupabaseService.swift`

### Step 3: Update Study Mode Loading
- Modify `loadFlashcards(for config)` in StudyViewImproved
- Implement different queries for each study mode
- Handle case when no cards are available

### Step 4: Add Flashcard Management
- Create flashcard browser in ManageView
- Add search and filtering capabilities
- Enable starring/unstarring of cards

## Expected Outcomes

After implementation:
1. ✅ Only "Causal Inference" articles will appear when that topic is selected
2. ✅ Study modes will load appropriate flashcards
3. ✅ Users can access and manage their created flashcards
4. ✅ Study sessions will show accurate progress and statistics
5. ✅ Spaced repetition will work properly for long-term learning

## Testing Plan

1. **RSS Filtering**: Select only "Causal Inference" and verify no blockchain articles appear
2. **New Cards Mode**: Should show all unstudied flashcards
3. **Smart Study**: Should show a mix of new and due cards
4. **Starred Review**: Should initially be empty, then show starred cards after starring some
5. **Quick Test**: Should show random selection of available cards

## Priority Order

1. **Fix RSS topic filtering** (immediate)
2. **Fix New Cards mode** (high priority - easiest to implement)
3. **Fix Smart Study mode** (high priority)
4. **Add flashcard management** (medium priority)
5. **Fix starred cards functionality** (medium priority)
6. **Implement Quick Test mode** (low priority)