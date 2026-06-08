# Delphi Coding Style Guide

This document defines the coding standards for the Blinki project. Following these rules keeps
the codebase clean, readable, and consistent across all source files — from the core library
(`Source\`) to demos (`Demos\`) and tests (`Tests\`).

> **Authoritative source**: `CLAUDE.md` contains the machine-readable version of these rules
> used by Claude Code. This file is the human-readable companion; when the two conflict, `CLAUDE.md`
> wins.

---

## 1. Naming Conventions

### Types and Classes

Use **PascalCase** with the `T` prefix for all class, record, and enumeration types.

```pascal
TMyClass
TUserSession
TConnectionState  // enumeration
```

Framework types additionally carry the `TTui` prefix:

```pascal
TTuiWidget
TTuiCanvas
TTuiKeyEvent
```

Exception types use `E` or `ETui`:

```pascal
EInvalidOperation
ETuiRenderError
```

### Interfaces

Use **PascalCase** with the `I` prefix:

```pascal
IDisposable
ITuiConsoleBackend
```

### Fields, Parameters, and Locals

| Scope          | Prefix | Example                       |
|----------------|--------|-------------------------------|
| Instance field | `F`    | `FItemCount`, `FVisible`      |
| Parameter      | `A`    | `AValue`, `ACanvas`, `ARect`  |
| Local variable | `L`    | `LText`, `LIndex`             |

Fields must be declared `strict private`. Local variables are declared **inline** at the point of
first use (see § 4 — Modern Constructs).

### Visual Components (VCL / FMX)

Use a short lowercase type abbreviation as a prefix:

| Control  | Prefix | Example         |
|----------|--------|-----------------|
| `TEdit`  | `edt`  | `edtUsername`   |
| `TButton`| `btn`  | `btnOk`         |
| `TLabel` | `lbl`  | `lblTitle`      |
| `TPanel` | `pnl`  | `pnlHeader`     |
| `TComboBox` | `cbo` | `cboCountry` |

---

## 2. Code Formatting and Layout

### Indentation

Use **2 spaces** per level. **Never use tabs.**

### Line Length

Keep lines at most **100 characters** wide. Wrap long expressions at a logical boundary
(after a comma, before a binary operator).

### `if` Statements — Body Always on a New Line

The statement controlled by `then` must **always** appear on its own line, indented. This rule
applies even to single-statement bodies. The same applies to `else` branches.

```pascal
// Correct
if Assigned(FItems) then
  FreeAndNil(FItems);

if LValue > 0 then
  ProcessValue(LValue)
else
  ResetState;

// Wrong — never write the body inline
if Assigned(FItems) then FreeAndNil(FItems);
```

### `begin` / `end`

Use `begin`/`end` for multi-statement blocks. For single-statement bodies after `if`, `for`,
`while`, or `repeat`, `begin`/`end` is optional but consistent — follow the pattern already used
in the surrounding code.

### No Alignment Spacing

Do **not** pad assignments or declarations with extra spaces to align columns. Use exactly one
space on each side of `:=` and one space after `:` in declarations.

```pascal
// Correct
Display := ADisplay;
IsDarkMode := AIsDarkMode;
FItemCount: Integer;

// Wrong — never add padding to align
Display    := ADisplay;
IsDarkMode := AIsDarkMode;
FItemCount  : Integer;
```

### Declaration Order

Within each visibility section (`strict private`, `protected`, `public`), keep members grouped
by kind and in **alphabetical order** within each group. The typical order is:

1. Fields
2. Private/protected methods (helpers)
3. Public methods and properties

When adding a new member, **insert it in the correct position** rather than appending it to the
end of the section.

---

## 3. Source File Structure

### File Encoding and Line Endings

All source files under `Source\`, `Demos\`, and `Tests\` (`.pas`, `.dpr`) must be saved as
**UTF-8 with BOM** (`EF BB BF`) and use **CRLF** (`\r\n`) line endings. Without the BOM, DCC32
falls back to the system code page (Windows-1252) and silently corrupts non-ASCII characters.
RAD Studio refuses to compile files with Unix LF-only line endings.

When creating files programmatically, apply the following PowerShell snippet to fix line endings:

```powershell
(Get-Content MyUnit.pas -Raw) -replace '(?<!\r)\n', "`r`n" | Set-Content MyUnit.pas -NoNewline
```

### License Banner

Every source file (`.pas` and `.dpr`) must begin with the 22-line license banner, placed
**before** the `unit`/`program` keyword and the XML-doc summary block. The `Unit:` field (line 14)
must match the file name exactly; pad it with spaces so the full line is exactly 66 characters wide
(formula: 48 − `len(filename)` trailing spaces before `}`).

```
{****************************************************************}
{                                                                }
{            ██████╗ ██╗     ██╗███╗   ██╗██╗  ██╗██╗            }
{            ██╔══██╗██║     ██║████╗  ██║██║ ██╔╝██║            }
{            ██████╔╝██║     ██║██╔██╗ ██║█████╔╝ ██║            }
{            ██╔══██╗██║     ██║██║╚██╗██║██╔═██╗ ██║            }
{            ██████╔╝███████╗██║██║ ╚████║██║  ██╗██║            }
{            ╚═════╝ ╚══════╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝            }
{                                                                }
{       Modern, beautiful Text User Interfaces for Delphi        }
{                                                                }
{****************************************************************}
{                                                                }
{   Unit:        Blinki.Core.Widget.pas                          }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}
```

### `uses` Section Order

List units in three logical groups, separated by a blank line or comment, in this order:

1. **System / RTL units** (`System`, `SysUtils`, `Classes`, `Math`, …)
2. **Third-party units** (if any)
3. **Project units** (`Blinki.*`, local demo/test units)

### `interface` vs `implementation`

Declare all public types, constants, and method signatures in the `interface` section. Keep the
`implementation` section focused on method bodies. In widget classes, follow the `Do*` virtual
hook contract (see `CLAUDE.md` — *Widget contract*).

---

## 4. Programming Best Practices

### Exception Handling

Use `try..finally` to guarantee resource cleanup regardless of whether an exception occurs. Use
`try..except` only when you intend to handle or transform the error.

```pascal
LStream := TFileStream.Create(APath, fmOpenRead);
try
  // work with LStream
finally
  LStream.Free;
end;
```

Avoid empty `except` blocks — they hide bugs silently.

### Memory Management

- **Parent owns children**: pass `Self` as the `AParent` argument when creating child widgets;
  the parent's destructor frees them.
- Use `TObjectList<T>(OwnsObjects := True)` for collections that own their elements.
- Use `FreeAndNil` to release and nil a field simultaneously. Always apply the `if Assigned`
  guard on its own line:

```pascal
// Correct
if Assigned(FItems) then
  FreeAndNil(FItems);
```

### Modern Constructs (Delphi 10.3+)

Prefer **inline `var`** declarations with type inference over top-of-routine `var` blocks:

```pascal
// Correct — inline var at point of use
var LText := FText;
var LIndex := 0;

for var LItem in FItems do
  ProcessItem(LItem);

// Wrong — old-style var block
var
  LText: string;
  LIndex: Integer;
begin
  LText := FText;
  ...
```

Use **generics** (`TList<T>`, `TDictionary<K,V>`, …) in preference to untyped containers.

Anonymous methods and closures are acceptable where they improve readability; keep them short.

### Property Setters — Guard-and-Invalidate

```pascal
procedure TMyWidget.SetCaption(const AValue: string);
begin
  if FCaption = AValue then
    Exit;
  FCaption := AValue;
  Invalidate;
end;
```

### No Redundant Default Initialization in Constructors

Delphi zero-initializes all instance fields automatically. Do **not** explicitly assign the
language default value in a constructor body:

| Type                 | Omit                         |
|----------------------|------------------------------|
| Integer / Float      | `FCount := 0;`               |
| Boolean              | `FVisible := False;`         |
| String               | `FCaption := '';`            |
| Object / Interface   | `FChild := nil;`             |
| Char                 | `FSeparator := #0;`          |

**Exception**: enumerated-type fields — keep the explicit assignment even when the value equals
the first member, because it documents intent and guards against future enum reordering.

Non-default values (`FItemIndex := -1`, `FVisible := True`) and parameter-derived assignments
are always kept.

### Cardinal / Integer Overflow in Arithmetic

When multiplying `Cardinal` or `Integer` values by constants ≥ `$80000000` (e.g. in hash
functions or LCG sequences), **promote all factors to `Int64` first** to prevent silent overflow:

```pascal
// Correct
LHash := Int64(LHash) * Int64($6B2BDB5) + Int64(AValue);

// Wrong — overflows silently on 32-bit
LHash := LHash * $6B2BDB5 + AValue;
```

### Build Tool

**Always compile with MSBuild** from the command line (after sourcing `rsvars.bat`). Never use
the IDE's Build button or invoke `dcc32.exe` directly. See `CLAUDE.md` — *Build / Run / Test*
for the exact commands.

---

## 5. Comments and Documentation

### Inline Comments

- Write all `//` line comments and `{ }` block comments in **English**.
- Use `//` for brief end-of-line or single-line notes.
- Use `{ }` for longer explanations or temporarily disabling code blocks.
- Use `(* *)` sparingly — typically only to disable a region that already contains `{ }` comments.
- Comment the **why**, not the **what**: the code itself says what it does; explain the reason
  behind a non-obvious decision.

```pascal
// Skip the focused widget — Tab cycles the focus ring at the app level
if AWid.Focused then
  Continue;
```

### XML-Doc `///` Comments

Place an XML-doc comment on every `public` type and every `public`/`published` member. The
`<summary>` description must go on a **new line** after the opening tag, indented by two spaces
inside the `///` block. The closing `</summary>` must be on its own line.

```pascal
// Correct
/// <summary>
///   Returns the number of items currently visible in the list.
/// </summary>
function VisibleCount: Integer;

// Wrong — text inline on the same line as <summary>
/// <summary>Returns the number of items currently visible in the list.</summary>
function VisibleCount: Integer;
```

Use `<param name="AName">`, `<returns>`, and `<remarks>` as needed for non-trivial methods.

### Colors and Theming

Never hardcode color values. Always read colors from `Theme.*` (e.g. `Theme.Primary`,
`Theme.Border`). Use `TTuiColors` constants instead of VCL `clXxx` names to avoid collisions.

Keep a `FXxxStyleOverride: Boolean` flag in each widget so that a caller-set style is not
silently overwritten by the next `DoApplyTheme` call.
