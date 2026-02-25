# Letter Playground App Design

## Product Goal
Create a playful app where a user speaks a prompt like "How do you spell flower?", sees the word as large draggable letters, and physically rearranges/interacts with those letters on screen.

## Core User Experience
1. User taps a microphone button and speaks.
2. App transcribes speech and extracts the target word.
3. App shows a keyboard for optional correction/editing.
4. On submit, letters appear large on a canvas (for example: `F L O W E R`).
5. User can touch, drag, rotate, and scatter letters around.
6. User can reset layout, hear the word spelled aloud, or save a snapshot.

## Primary Audience
- Early learners practicing spelling.
- Parents/teachers guiding phonics and letter recognition.
- Kids who benefit from tactile/kinesthetic interaction.

## MVP Feature Set
- Voice input using device speech-to-text.
- Word extraction from phrases like:
  - "How do you spell flower?"
  - "Spell elephant."
  - "Flower."
- Text fallback input with standard keyboard.
- Large letter tiles on a full-screen interactive canvas.
- Multi-touch interactions:
  - Drag letter.
  - Pinch to resize.
  - Rotate with two-finger gesture.
- Utility actions:
  - `Shuffle`
  - `Reset`
  - `Speak word`
  - `Clear`
- Basic persistence:
  - Save last 5 words locally.

## Interaction Design
### Screen 1: Capture
- Top: Prompt text ("Say a word to spell")
- Center: Big mic button
- Bottom: Keyboard input field and `Create Letters` CTA

### Screen 2: Letter Canvas
- Full-bleed canvas with high-contrast background
- Letter tiles with rounded cards and bold typography
- Floating toolbar:
  - `Back`
  - `Shuffle`
  - `Reset`
  - `Speak`
  - `Save`

### Gesture Rules
- Single tap: select letter (shows glow/outline)
- Drag: move selected letter
- Two-finger rotate: rotate selected letter
- Pinch: resize selected letter within min/max bounds
- Double tap on letter: play letter sound (`F`, `L`, etc.)

## Visual Direction
- Tone: cheerful, clean, tactile.
- Palette:
  - Background: warm off-white (`#F7F3E9`)
  - Primary action: coral (`#FF6B4A`)
  - Accent: teal (`#2FA39A`)
  - Letter cards: alternating pastel set for easy distinction
- Typography:
  - Titles/UI: `Nunito` or `Baloo 2`
  - Letters: heavy rounded font for readability
- Motion:
  - Letters "pop in" with spring animation
  - Shuffle uses quick scatter-and-settle animation

## Functional Logic
### Input Processing
- Normalize transcript:
  - lowercase
  - remove punctuation
  - parse for patterns (`spell X`, `how do you spell X`)
- Validate output word:
  - alphabetic characters only in MVP
  - max length 20

### Letter Model
- Each tile contains:
  - `id`
  - `char`
  - `x, y`
  - `rotation`
  - `scale`
  - `zIndex`
- Canvas state supports undo stack (minimum depth 10).

## Accessibility
- Voice and keyboard parity.
- Dynamic type support for controls.
- High-contrast mode toggle.
- Haptic feedback on tile pickup/drop.
- Screen-reader labels for all controls and each letter.

## Technical Architecture (Recommended)
### Mobile-first stack
- `React Native` + `Expo`
- Speech: `expo-speech` (TTS), platform speech recognition plugin
- Gestures/animation: `react-native-gesture-handler` + `react-native-reanimated`
- State: `Zustand` or `Redux Toolkit`
- Local storage: `AsyncStorage`

### Core Modules
- `speechInputService`
- `wordParser`
- `letterLayoutEngine`
- `gestureController`
- `canvasStateStore`

## Non-Goals for MVP
- Multi-word sentence layout.
- Multiplayer collaboration.
- Cloud sync/account system.
- Advanced phonics curriculum.

## Success Metrics
- Time from app open to first interactive word < 15 seconds.
- 80%+ successful word extraction on first try.
- Median session length > 3 minutes.
- Repeat usage: 3+ sessions per week for active users.

## Build Plan
1. Implement Capture screen (voice + keyboard).
2. Implement parser and validation.
3. Render letters in static large cards.
4. Add drag interaction.
5. Add rotate/scale gestures.
6. Add toolbar actions (`shuffle/reset/speak/save`).
7. Add polish: animations, sounds, accessibility.
8. Add lightweight analytics events.

## Future Enhancements
- "Trace the letter" mode with finger drawing.
- Phonics mode that groups letter sounds.
- Theme packs (space, garden, animals).
- Teacher mode with weekly word lists.
