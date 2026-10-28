# ColoringFun

An iPad app for toddlers: a launcher with big tiles that opens small
apps for drawing, spelling and letter tracing. SwiftUI, iPad only, iOS 15+.

## What's in it

- **Coloring Fun.** A full drawing app for parents: crayon, marker, chalk and
  glitter brushes, a brush builder, 20 Crayola colors plus a color picker, size
  and opacity, emoji stamps in five categories, undo and an eraser.
- **Kids Mode.** The same canvas made for a toddler: no menus, 68pt buttons, two
  stamps per category, and a sound when a stamp lands. Kids can make their own
  brushes with simple sliders ("more grainy", "more bleed").
- **Spelling Fun.** Say a word out loud. Its letters scatter as tiles, and
  dragging a tile speaks the letter.
- **Trace Fun.** Say a word, then trace each letter in rainbow paint.
- **Weather Fun** (in progress). A SpriteKit scene that shows today's weather
  with rain, snow and sun animations and ambient sound.
- **Ask for a new app.** Unused tiles let a kid dictate an app idea, which is
  emailed to a parent.

## Built around real feedback

The first version went to my wife for a test run. Her notes came back blunt: no
default stamp, the eraser is in the wrong place, the size slider is at the
bottom, the backgrounds look dumb. Each round
became a design doc and a plan in `docs/plans/`, and the app was rebuilt to
match. All 11 items from the first round are done.

## How it's built

- `ColoringApp/` holds the hub, the registry of mini-apps and the two coloring
  modes. Adding an app is one entry in `AppRegistry.apps`.
- Each newer mini-app is its own local Swift package under `Packages/`, so it
  builds and tests on its own (`Packages/WeatherFunTests` runs on macOS).
- Drawing elements (strokes and stamps) share one ordered list, so layering is
  correct by default, with a toggle to keep stamps on top.
- Built with AI coding agents working from the design docs and plans in
  `docs/plans/`. Architecture notes are in `docs/CONTEXT.md`.

## Build

Open `ColoringFun.xcodeproj` in Xcode and run the `ColoringFun` scheme on an
iPad or iPad simulator.
