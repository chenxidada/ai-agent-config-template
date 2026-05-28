# Code Analysis Report

## Analysis Scope

<!-- What was analyzed: full repo, specific module, specific file, specific angle -->

## Executive Summary

<!-- 3-5 sentence overview for someone who has never seen this codebase -->

## Technology Stack

<!-- Languages, frameworks, build tools, test tools, package managers, key dependencies -->

## Architecture Overview

### High-Level Structure

<!-- Module/directory layout with purpose of each major area -->

### Layer Diagram

<!-- If applicable: presentation / API / business logic / data / infrastructure layers -->

### Module Dependency Map

<!-- Which modules depend on which. Call direction. Circular dependencies if any. -->

## Core Abstractions and Design Patterns

<!-- Key abstractions (classes, interfaces, types) that define the system's vocabulary -->
<!-- Design patterns used (and whether they are used consistently) -->

## Data Flow

### Primary Data Paths

<!-- How data enters, transforms, and exits the system -->

### State Management

<!-- Where state lives, how it is mutated, who owns it -->

## Entry Points

<!-- User-facing entry points: CLI commands, HTTP endpoints, event handlers, UI routes, etc. -->

## External Dependencies

### Runtime Dependencies

<!-- Key third-party libraries and their roles -->

### Development Dependencies

<!-- Build tools, linters, test frameworks, CI configuration -->

### External Services

<!-- APIs, databases, message queues, file systems the code interacts with -->

## Code Quality Observations

### Strengths

<!-- Well-designed areas, good patterns, consistent conventions -->

### Technical Debt and Risk Areas

<!-- Inconsistencies, outdated patterns, missing tests, overly complex areas -->

### Convention Summary

<!-- Naming, file organization, error handling, logging patterns observed -->

## Key Files Index

<!-- Files a new developer should read first, in recommended order, with 1-line explanation each -->

## Unverified / Requires Runtime Confirmation

<!--
  静态代码分析无法确认的内容。这是分析报告最重要的部分之一 —— 告诉读者"这里是分析的边界，不要假设以下内容正确"。
  分为三类，每类需要不同的验证方式。
  必须填写 —— 空章节意味着你声称已验证一切，这对静态分析几乎不可能。
-->

### Needs Runtime Verification（需要运行时验证）

<!-- 代码逻辑存在，但静态分析无法确认是否正确工作。例如：并发安全、性能假设、超时处理、网络行为 -->

| # | 描述 | 涉及代码 | 需要什么验证 |
|---|------|---------|-------------|
| — | — | — | — |

### Structural Observations Only（仅结构观察，未验证函数体）

<!-- 函数签名存在、编译通过，但函数体未被完整阅读。不要假设这些函数工作正确 -->

| # | 文件:函数 | 观察到的 | 未验证的 |
|---|----------|---------|---------|
| — | — | — | — |

### Inferences / Hypotheses（推测，未从代码确认）

<!-- 基于命名约定、文档注释、调用模式的推测，未找到明确的代码证据 -->

| # | 推测 | 依据 | 风险 |
|---|------|------|------|
| — | — | — | — |

## Code Review Findings

<!-- INCLUDE THIS SECTION ONLY when the analysis focus is "review" or code review related -->
<!-- DELETE THIS SECTION for architecture/structure analysis -->

### Critical Issues

<!-- Bugs, logic errors, security vulnerabilities, data loss risks -->

### Should-Fix Issues

<!-- Error handling gaps, edge cases, performance concerns, maintainability problems -->

### Minor / Nitpick

<!-- Naming, style, minor inconsistencies -->

### Improvement Suggestions

<!-- Specific, actionable recommendations with reasoning -->
