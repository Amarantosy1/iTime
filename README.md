# iTime

> A native macOS menu bar app that turns your calendars into a personal time dashboard.

[![Platform](https://img.shields.io/badge/platform-macOS-111111)](#)
[![Swift](https://img.shields.io/badge/swift-6-orange)](#)
[![UI](https://img.shields.io/badge/UI-SwiftUI-blue)](#)
[![Tests](https://img.shields.io/badge/tests-75%20passing-brightgreen)](#)

`iTime` answers one simple question:

**我的时间去哪了？**

It reads your system calendars, aggregates real scheduled time, and presents it in a fast menu bar view plus a richer desktop dashboard. It also includes an AI review flow that can ask follow-up questions about specific events, generate summaries, and keep local history.

## Highlights

- Native macOS menu bar experience built with `SwiftUI`
- Reads calendars and events through `EventKit`
- Supports `今天 / 本周 / 本月 / 自定义` ranges
- Excludes all-day events from statistics
- Overview dashboard with:
  - key metrics
  - hourly/day/weekly stacked charts
  - calendar distribution chart
  - AI review entry and latest summary
- Dedicated AI conversation window with:
  - multi-turn review flow
  - per-service model selection before each session
  - local history archive
  - editable past summaries
- Native Settings window with:
  - calendar selection
  - built-in AI services
  - custom `OpenAI-compatible` services
- Chinese UI, dark mode support, app icon, and local persistence

## What Makes It Useful

Most calendar tools are built for planning. `iTime` is built for reflection.

Instead of showing what you intended to do, it shows what your calendar actually captured:

- how much time each calendar took
- how your time was distributed across the day
- where your schedule became fragmented
- what changed over time
- how an AI reviewer interprets those patterns after asking for missing context

That makes it useful for:

- work log reviews
- study planning retrospectives
- workload balance checks
- recurring meeting audits
- weekly or monthly personal reviews

## Core Features

### Menu Bar Snapshot

- Quick range switching
- Total tracked time at a glance
- Horizontal distribution bars by calendar
- Fast entry into the full dashboard

### Overview Dashboard

- Total duration
- Event count
- Average daily duration
- Longest day
- Screen Time-style stacked chart
- Donut chart with calendar legend
- Custom date range support

### AI Review

- Reads event titles, not just aggregated buckets
- Starts by asking you about concrete scheduled items
- Produces a structured summary after the conversation ends
- Stores history locally
- Lets you revisit and edit previous summaries

### AI Services

Built-in services:

- `OpenAI`
- `Anthropic`
- `Gemini`
- `DeepSeek`

Custom services:

- `OpenAI-compatible` endpoints

Each service stores its own:

- `Base URL`
- API key
- model list
- default model
- enabled state

## Project Structure

```text
iTime.xcodeproj/
Sources/iTime/
  App/          App state and orchestration
  Domain/       Models for calendars, overview, AI services, AI history
  Services/     EventKit access, statistics aggregation, AI adapters
  Support/      Persistence, formatting, keychain, archive storage
  UI/           Menu bar, dashboard, settings, AI conversation, theme
Tests/iTimeTests/
Package.swift
```

## Getting Started

### Open in Xcode

1. Open `iTime.xcodeproj`
2. Select the `iTime` scheme
3. Choose `My Mac`
4. Run with `Cmd + R`

### First Launch

`iTime` needs Calendar access.

If access was denied previously:

1. Open `System Settings`
2. Go to `Privacy & Security > Calendars`
3. Enable access for `iTime`

## Build & Test

```bash
swift build
swift test
xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' build
xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' test
```

Current verification status:

- `swift test` passes with **75** tests
- `xcodebuild ... test` passes

## Design Direction

The app intentionally stays close to native macOS behavior:

- menu bar first
- dedicated desktop overview window
- native Settings window
- system appearance following
- restrained glass/material styling instead of a custom design system

The goal is not to become a generic productivity suite. The goal is to make calendar-based time review feel immediate, personal, and native.

## Current Scope

Implemented:

- calendar-based time aggregation
- overview dashboard
- custom ranges
- AI review conversation
- AI summary history
- editable review history
- multi-service AI configuration

Not in scope yet:

- task management
- cross-device sync
- Health / sleep ingestion
- background AI automation
- external analytics backend

## Why This Repo Exists

This project is a focused exploration of three things together:

- native macOS menu bar product design
- calendar-derived personal analytics
- AI-assisted time reflection with local-first history

If you want a compact macOS codebase that combines `EventKit`, `SwiftUI`, native settings, local persistence, charts, and AI service routing in one app, this repo is a good reference point.
