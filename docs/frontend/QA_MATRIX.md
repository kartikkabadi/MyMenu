# Frontend QA Matrix

This matrix is the release and review gate for MyMonitor's native frontend. A build succeeding is necessary but does not establish UI quality.

## 1. Required test environments

### Hardware

At minimum:

- Apple silicon MacBook with built-in display.
- One DDC-capable external monitor connected directly when possible.
- One external monitor or connection path that uses software/shade fallback.
- Two external monitors simultaneously.
- USB-C/DisplayPort and HDMI/dongle paths when available.

### Software appearances

- Light.
- Dark.
- Graphite accent.
- One non-blue accent color.
- Increased Contrast.
- Reduce Transparency.
- Reduce Motion.
- Differentiate Without Color.
- VoiceOver on.

### Window/display contexts

- Status item on main display.
- Menu bar on a secondary display.
- Fullscreen Space.
- Multiple Spaces.
- Settings active and inactive.
- Settings at minimum, default, and wide sizes.

## 2. Build and static gates

| ID | Requirement | Pass condition |
|---|---|---|
| B-01 | Project generation | `./scripts/generate_xcodeproj.sh` exits 0. |
| B-02 | Debug build | Xcode 26 Debug build exits 0 with signing disabled in CI. |
| B-03 | Whitespace | `git diff --check` exits 0. |
| B-04 | Dependencies | No new third-party UI dependency. |
| B-05 | Fixed colors | No new fixed RGB UI color without documented exception. |
| B-06 | Custom material | No new custom blur/glass/card abstraction without approved decision entry. |
| B-07 | Dead UI | No hidden placeholder or unreachable experimental surface. |
| B-08 | Main-thread boundary | Views contain no DDC/display enumeration/private API calls. |

## 3. Required deterministic fixtures

The preview/test fixture suite must cover:

| Fixture | Required visible behavior |
|---|---|
| Loading without cache | Compact detecting state; footer available. |
| Empty | No external displays copy and Refresh. |
| One hardware display | One row, no redundant heading, 72% example. |
| One software display | Fallback label visible. |
| One shade display | Fallback label and disclosure available. |
| One unavailable display | No slider; Retry and diagnostics actions. |
| Two mixed displays | Conditional heading, stable rows. |
| Four displays | Scrolling starts before popover exceeds max height; footer stationary. |
| Eight displays | Stable performance/focus/order under overflow. |
| Long names | Values and sliders remain usable; names truncate intentionally. |
| Checking method | Status updates without slider/layout jump. |
| Disconnection | Row removal and empty transition. |
| Error recovery | Retry transitions back to ready state. |

Every fixture must be viewable in Light and Dark. Key fixtures must also be captured in Increased Contrast and Reduce Transparency.

## 4. Status item and popover

| ID | Scenario | Pass condition |
|---|---|---|
| P-01 | Resting status item | Monochrome template `display` symbol; no persistent color/animation. |
| P-02 | Click | Popover opens below the clicked status item on the correct display. |
| P-03 | Re-click | Popover closes without leaving a stale window. |
| P-04 | Outside click | Transient popover dismisses. |
| P-05 | Escape | Popover dismisses. |
| P-06 | Fullscreen | Popover appears in the active fullscreen Space as expected for a status item. |
| P-07 | Rapid toggling | Ten rapid open/close cycles produce one popover and no duplicate hosting controllers. |
| P-08 | Open latency | First visible frame target under 100 ms and does not wait for DDC. |
| P-09 | No layout jump | Cached rows do not resize/reorder when method status refines. |
| P-10 | Content height | One-row popover contains no forced blank area. |
| P-11 | Overflow | Many rows scroll while footer remains fixed. |
| P-12 | Footer | Preferences leading, Quit trailing, one native divider above. |
| P-13 | Preferences | Opens/focuses one Settings window and dismisses popover. |
| P-14 | Quit | Performs orderly teardown and terminates. |

## 5. Monitor row and brightness interaction

| ID | Scenario | Pass condition |
|---|---|---|
| S-01 | Direction | Moving left darkens; moving right brightens for every control tier. |
| S-02 | Initial value | UI reflects cached/current value and opening popover does not change brightness. |
| S-03 | Pointer drag | Thumb and percentage update continuously on the next visual frame. |
| S-04 | Hardware throttle | DDC throttling does not make the thumb stutter or reverse. |
| S-05 | Commit | Final release persists the intended value. |
| S-06 | Arrow keys | Focused slider adjusts predictably and displays focus ring. |
| S-07 | Boundary | Values clamp at configured min/max with no wraparound. |
| S-08 | Failure | Write failure becomes explicit state; UI does not silently jump back. |
| S-09 | Display identity | Adjusting one row never changes another unless an explicit sync feature exists. |
| S-10 | Percentage | Whole percent, monospaced digits, no width jitter between values. |
| S-11 | Long name | Name truncates before percentage/slider becomes unusable. |
| S-12 | Decorative symbols | Moon/sun do not receive keyboard or VoiceOver focus. |

## 6. Display lifecycle

| ID | Scenario | Pass condition |
|---|---|---|
| D-01 | Connect first external display | Empty state becomes one row without reopening app. |
| D-02 | Disconnect last display | Row disappears and empty state replaces it. |
| D-03 | Connect second display | Heading appears and stable second row is inserted. |
| D-04 | Disconnect one of many | Remaining rows keep identity/value/order. |
| D-05 | Wake | Rows recover without duplicate displays or forced brightness jump. |
| D-06 | Space change | Shade/fallback remains visually correct; popover data does not reset. |
| D-07 | Mirroring | Mirrored set is represented once when one action controls it. |
| D-08 | Reorder/layout change | Row identity remains stable; order follows specified policy. |
| D-09 | Backend refinement | Hardware-to-fallback state changes status copy without replacing wrong row. |

## 7. Popover state and copy

| ID | State | Pass condition |
|---|---|---|
| C-01 | Empty | Exact concise title/body/action from product spec or approved updated copy. |
| C-02 | Loading | No indefinite spinner and no skeleton cards. |
| C-03 | Hardware | Uses user-facing `Hardware control` if method label is visible. |
| C-04 | Software | Uses `Software control`; no technical tier label. |
| C-05 | Shade | Uses `Display shade`; disclosure explains physical backlight is unchanged. |
| C-06 | Unavailable | `Brightness unavailable`; no disabled misleading slider. |
| C-07 | Error action | Retry applies only to the affected display. |
| C-08 | Technical language | DDC/VCP/IOKit/private framework names absent outside diagnostics. |
| C-09 | Tone | No exclamation marks, marketing copy, blame, or unnecessary apology. |

## 8. Settings window

| ID | Scenario | Pass condition |
|---|---|---|
| W-01 | Open | Standard Mac window chrome and traffic lights. |
| W-02 | Duplicate prevention | Repeated Preferences action focuses one existing window. |
| W-03 | Close | Closing Settings leaves status app running. |
| W-04 | Default size | Opens around 720 × 500 and remains balanced. |
| W-05 | Minimum size | At 620 × 420, no clipped controls or inaccessible content. |
| W-06 | Wide size | Content does not stretch into unusably long rows; detail remains readable. |
| W-07 | Restoration | Previous reasonable size/position restores where supported. |
| W-08 | Sidebar | Native selection, keyboard navigation, accent, and focus. |
| W-09 | Sections | Only implemented sections/controls visible. |
| W-10 | Inactive appearance | Window and sidebar recede using system behavior; no forced active tint. |
| W-11 | Form hierarchy | Uses native Form/Section/LabeledContent rather than repeated custom cards. |
| W-12 | Scroll | Long detail content scrolls natively with no nested conflicting scroll views. |

## 9. General settings

| ID | Scenario | Pass condition |
|---|---|---|
| G-01 | Launch at login off→on | System registration succeeds and UI reflects actual state. |
| G-02 | Launch at login on→off | System unregisters and UI reflects actual state. |
| G-03 | Registration failure | Contextual explanation and retry; toggle does not lie. |
| G-04 | Cosmetic options | No option exists unless behavior is real and testable. |
| G-05 | Updates | No automatic-update control until an updater exists. |

## 10. Displays settings

| ID | Scenario | Pass condition |
|---|---|---|
| DS-01 | Connected list | Connected displays are identified correctly. |
| DS-02 | Remembered disconnected | Only displays with saved settings appear, separated and labeled. |
| DS-03 | Open detail | Opening detail does not change physical brightness. |
| DS-04 | Min/max validation | Minimum cannot exceed maximum. |
| DS-05 | Clamp semantics | Existing current brightness changes only after explicit user action/confirmation. |
| DS-06 | Automatic method | Default and recommended; selected when no override exists. |
| DS-07 | Unsupported method | Cannot be enabled silently; explanation is readable. |
| DS-08 | Forget | Removes only selected display preferences after appropriate confirmation. |

## 11. Keyboard and focus

| ID | Scenario | Pass condition |
|---|---|---|
| K-01 | Popover tab order | Sliders, contextual controls, Preferences, Quit in reading order. |
| K-02 | Reverse traversal | Shift-Tab reverses correctly. |
| K-03 | Space/Return | Native activation behavior; no duplicate action. |
| K-04 | Escape | Dismisses innermost sheet/popover first. |
| K-05 | Settings sidebar | Arrow keys change selection natively. |
| K-06 | Focus visibility | Native focus ring never suppressed. |
| K-07 | Shortcut recorder | Records, rejects conflicts, clears, and displays native glyphs. |
| K-08 | Permissions | Keyboard feature does not request unrelated Accessibility/Screen Recording access. |

## 12. VoiceOver

| ID | Scenario | Pass condition |
|---|---|---|
| A-01 | Status item | Reads `MyMonitor`, with useful help. |
| A-02 | Slider | Reads `Brightness for <name>, <n> percent, adjustable`. |
| A-03 | Duplicate value | Percentage text does not cause redundant announcement. |
| A-04 | Decorative icons | Moon/sun and decorative display icon hidden. |
| A-05 | Fallback | Method and limitations readable in logical order. |
| A-06 | Error | Unavailable state and recovery actions understandable without visual context. |
| A-07 | Connection | Meaningful connect/disconnect event announced once. |
| A-08 | Settings | Sidebar, sections, labels, values, help, and destructive actions have correct roles. |
| A-09 | Full task | Keyboard/VoiceOver user can adjust each display and open Settings without pointer. |

## 13. Appearance and accessibility visuals

| ID | Environment | Pass condition |
|---|---|---|
| V-01 | Light | Native hierarchy, no washed-out secondary text. |
| V-02 | Dark | No hard-coded light fills/borders; slider/status legible. |
| V-03 | Graphite | No forced blue; controls honor system accent. |
| V-04 | Non-blue accent | Selection/toggle/slider adapt without conflicting custom colors. |
| V-05 | Increased Contrast | Boundaries/focus strengthen through system behavior; no clipped borders. |
| V-06 | Reduce Transparency | Popover/sidebar remain opaque enough; content does not depend on background. |
| V-07 | Reduce Motion | Optional row transitions simplify/disable; state remains clear. |
| V-08 | Differentiate Without Color | Errors/method/selection have text or shape cues. |
| V-09 | Active/inactive | Settings uses system focus recession. |

## 14. Localization and resilience

| ID | Scenario | Pass condition |
|---|---|---|
| L-01 | 30% expansion | Labels wrap/truncate intentionally; controls remain accessible. |
| L-02 | Long display name | Percentage and slider remain visible. |
| L-03 | Very long error | Popover remains within max width/height and provides scroll only where needed. |
| L-04 | RTL readiness | No hard-coded left/right semantic assumptions where leading/trailing should be used. |
| L-05 | Number formatting | Percentage uses locale-aware formatting where appropriate. |
| L-06 | Sentence construction | No concatenated localized fragments. |

## 15. Performance and energy

| ID | Scenario | Target/pass condition |
|---|---|---|
| PERF-01 | Popover first frame | Target <100 ms from click on supported hardware; never blocked on DDC. |
| PERF-02 | Slider visual response | Next display frame. |
| PERF-03 | Main thread | No synchronous DDC probe/write or display enumeration during popover open. |
| PERF-04 | Idle popover closed | No UI polling timer. |
| PERF-05 | Idle Settings closed | No UI polling timer. |
| PERF-06 | Rapid drag | No unbounded task/work-item creation; backend throttle coalesces writes. |
| PERF-07 | Four/eight fixtures | Smooth scrolling and focus with no obvious layout churn. |
| PERF-08 | Repeated opens | No accumulating windows, observers, hosts, or memory growth. |

Performance numbers are targets that should be instrumented. A regression needs measured justification.

## 16. Screenshot set required for UI-changing PRs

Capture the relevant subset:

1. Empty popover — Light.
2. One hardware display — Light and Dark.
3. Two mixed displays — Light and Dark.
4. Four-display scrolling popover.
5. Fallback disclosure.
6. Unavailable/retry state.
7. General Settings — Light and Dark.
8. Displays Settings detail.
9. Advanced diagnostics.
10. Increased Contrast popover.
11. Reduce Transparency popover/Settings.
12. Long-name/text-expansion fixture.

Screenshots are evidence, not golden truth. Native OS updates may alter rendering while preserving the contract.

## 17. Real-hardware sign-off template

```markdown
Mac:
macOS:
MyMonitor commit:

Display 1:
Connection path:
Expected control method:
Observed control method:

Display 2:
Connection path:
Expected control method:
Observed control method:

Checks:
- [ ] Initial brightness preserved on launch
- [ ] Slider direction correct
- [ ] Drag responsive
- [ ] Persist/relaunch correct
- [ ] Hot-plug correct
- [ ] Sleep/wake correct
- [ ] Spaces/fullscreen correct
- [ ] Multiple rows target correct display
- [ ] Popover correct menu bar/display

Notes:
```

## 18. Release-blocking failures

Any of these blocks merge/release:

- Slider direction differs by backend.
- Opening/launching changes brightness without user intent.
- Popover blocks on display probing.
- Duplicate/stale popovers or Settings windows.
- A connected display row controls the wrong display.
- Unavailable control is shown as a functioning slider.
- Keyboard/VoiceOver cannot adjust brightness.
- Fixed dark/light styling breaks another appearance.
- Custom glass or cards violate the hierarchy contract.
- Settings exposes nonfunctional controls.
- App requests unrelated privacy permissions.
