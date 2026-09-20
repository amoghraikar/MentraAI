# Mentra — UI/UX Specifications & Design System

> **Document Version:** 2.0  
> **Status:** Implemented  
> **Design Philosophy:** Minimalist, calm, distraction-free study environment  
> **Theme Support:** Dark Mode First (Calm Obsidian & Forest Green accents)  

---

## 1. Design Principles

1. **Cognitive Calm**: Interfaces avoid unnecessary visual noise, flashing animations, or aggressive alert colors.
2. **Deep Focus Affirmation**: Active study sessions enter a distraction-free HUD mode where non-essential controls fade out.
3. **Transparent Intelligence**: AI suggestions and CV focus metrics are presented objectively without gamified stress triggers.
4. **Accessible Hierarchy**: Distinct typographic scales and consistent padding ensure legibility on desktop and small screens alike.

---

## 2. Color Palette & Theming Tokens

Mentra uses a bespoke color palette defined in `apps/mentra/lib/core/theme/app_colors.dart`:

```
┌────────────────────────────────────────────────────────────────────────┐
│ PRIMARY & ACCENT COLORS                                                │
│ Primary Brand:        #10B981  (Emerald Green — Focus & Progress)      │
│ Primary Container:    #134E4A  (Deep Pine Container)                   │
│ Accent Indigo:        #6366F1  (Deep Conceptual Learning / AI)         │
│ Accent Amber:         #F59E0B  (Milestones & Goal Deadlines)           │
│ Danger Red:           #EF4444  (Distraction Alerts & Fatigue Warnings) │
└────────────────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────────────┐
│ DARK MODE SURFACE SCALE (OBSIDIAN PALETTE)                             │
│ Background:           #090D0C  (Ultra-deep study dark)                 │
│ Surface (Cards):      #111916  (Subtle elevated surface)               │
│ Surface Hover:        #17231F  (Interactive card hover)                │
│ Border & Outlines:    #1F322B  (Low-contrast structural dividing lines)│
└────────────────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────────────┐
│ TEXT & CONTENT SCALE                                                   │
│ Text Primary:         #F3F4F6  (High contrast content & headers)       │
│ Text Secondary:       #9CA3AF  (Metadata, captions, subtle labels)     │
│ Text Muted:           #6B7280  (Timestamps, inactive icons)            │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Typography Hierarchy

Defined in `apps/mentra/lib/core/theme/app_typography.dart` using modern sans-serif typography:

| Style Token | Size | Weight | Line Height | Usage |
| :--- | :--- | :--- | :--- | :--- |
| `displayLarge` | 32px | Bold (700) | 40px | Workspace banner headers, session complete titles |
| `headlineMedium` | 24px | SemiBold (600) | 32px | Section titles (Notes, Goals, Analytics) |
| `titleMedium` | 18px | Medium (500) | 24px | Card headers, subject cards, modal titles |
| `bodyLarge` | 16px | Regular (400) | 24px | Note editor body text, AI Coach messages |
| `bodyMedium` | 14px | Regular (400) | 20px | Standard descriptions, milestone labels |
| `labelSmall` | 11px | SemiBold (600) | 16px | Badges, tags, chart axes, uppercase metadata |

---

## 4. Spacing & Radius Tokens

- **Spacing** (`core/theme/app_spacing.dart`):
  - `xs`: 4px | `sm`: 8px | `md`: 16px | `lg`: 24px | `xl`: 32px | `xxl`: 48px
- **Radius** (`core/theme/app_radius.dart`):
  - `borderSm`: 6px (Badges & tags)
  - `borderMd`: 12px (Buttons & inputs)
  - `borderLg`: 16px (Cards, dialogs & modals)
  - `borderXl`: 24px (Large containers & HUD cards)

---

## 5. Core Reusable Components

### 5.1. `MentraButton`
- **Variants**: Primary (Emerald solid), Secondary (Outlined dark), Destructive (Red accent), Ghost (Text only).
- **States**: Default, Hover, Focused, Disabled, Loading (embedded spinner without size jumping).

### 5.2. `MentraCard`
- Elevated surface container with subtle border (`#1F322B`), smooth rounded corners (16px), and optional tap/hover highlight.

### 5.3. `MentraBadge`
- Color-coded compact pill used for Subject tags, Session status (`Active`, `Completed`), and Distraction alerts.

### 5.4. `MentraProgressBar`
- Animated linear progress bar with customizable fill color and rounded caps. Used in Goal milestone tracking and Subject mastery.

### 5.5. `MentraStatCard`
- Dashboard metric card with title, large numeric value, trend indicator (e.g. `+12% this week`), and icon badge.

---

## 6. Key Screen Specifications

### 6.1. Workspace Shell (`WorkspaceLayout`)
- **Left Sidebar**: Collapsible navigation bar containing links to Home, Subjects, Study Sessions, Notes, Goals, Analytics, and AI Coach.
- **Top Header**: Breadcrumbs, current subject indicator, active session shortcut, and profile avatar.
- **Content Area**: Responsive flexbox layout adapting gracefully between desktop (1440px) and tablet/mobile viewports.

### 6.2. Five-Stage Study Session Screens
- **Setup Dialog**: Modal allowing subject selection, topic focus, timer duration slider, and focus monitoring toggle.
- **Study Prep HUD**: Fullscreen dark view with 5-second countdown ring, camera preview rectangle, and intention commitment.
- **Active Session HUD**: Minimalist high-contrast timer display, live focus score radial gauge, and subtle distraction badge alerts.
- **Reflection Dialog**: 4 visual feedback tiles (Great / Good / Distracted / Tired) and optional notes input.

### 6.3. AI Coach Workspace (`AiCoachPage`)
- Split-panel or centered conversational interface.
- Progressive token-by-token streaming bubble rendering.
- Markdown syntax highlighting for code blocks and math formulas.
- Action toolbar: "Cancel Generation", "Clear History", "Export Note".

### 6.4. Analytics Dashboard (`AnalyticsPage`)
- Range selector tab bar (`7 Days`, `30 Days`, `90 Days`, `All Time`).
- High-level metric grid (Total Time, Average Focus Score, Total Sessions).
- Daily study minutes & focus score trend bar/line visualization.
- Distraction breakdown donut/progress chart.
