# AI playbook: reviewing Python code for standard compliance

## Goal
This guide targets AI assistants that review Python code for adherence to common language standards. The assistant MUST NOT modify code automatically—only flag issues and suggest fixes.

## Principles
1. **Do not auto-fix** — highlight problems, don't rewrite the file.
2. **Provide actionable fixes** — explain how to resolve each issue.
3. **Ask for consent** — confirm with the user before applying any change.
4. **Stay constructive** — reference the violated rule and reasoning.
5. **Respect context** — deviations can be intentional; clarify when unsure.

---

## Standards to check

### 1. PEP 8 basics

#### 1.1 Indentation & formatting
Check:
- Spaces instead of tabs (4 spaces per indent).
- Max line length: 79 chars for code, 72 for comments.
- Blank lines: two between top-level defs/classes, one inside classes.

```python
# ❌ Bad — 2-space indent
def function():
  return True

# ❌ Bad — overly long line
def very_long_function_name(argument1, argument2, argument3, argument4, argument5, argument6, argument7, argument8):
    pass

# ✅ Good — 4-space indent
def function():
    return True

# ✅ Good — breaking long signature
def very_long_function_name(
    argument1, argument2, argument3,
    argument4, argument5, argument6,
):
    pass
```

Report template:
```
❌ Line 2 uses a 2-space indent. PEP 8 requires 4 spaces per level.
Suggested change:
def function():
    return True
Fix now? (y/n)
```

#### 1.2 Spaces around operators
Check:
- One space around assignments/comparisons.
- One space after commas.
- No spaces just inside parentheses/brackets.
- No space before colons (slice syntax excluded).

```python
# ❌ Bad
x=1
y = 2+3
my_list = [ 1,2,3 ]
my_dict = {'key' : 'value'}

# ✅ Good
x = 1
y = 2 + 3
my_list = [1, 2, 3]
my_dict = {'key': 'value'}
```

#### 1.3 Imports
Check:
- At file top.
- Grouped: stdlib, third-party, local.
- One import per line (`from module import a, b` allowed).
- Prefer absolute imports.

```python
# ❌ Bad
import sys, os
from mypackage import *

# ✅ Good
import os
import sys

from mypackage import module1, module2
```

---

### 2. Naming conventions

#### 2.1 Styles
Check:
- Variables/functions: `snake_case`.
- Classes: `PascalCase`.
- Constants: `UPPER_SNAKE_CASE`.
- Private attrs: `_leading_underscore`.
- Do not shadow built-ins.

```python
# ❌ Bad
def MyFunction():
    MyVariable = 5
    return MyVariable

class my_class:
    def __init__(self):
        self.publicAttr = 1

# ✅ Good
def my_function():
    my_variable = 5
    return my_variable

class MyClass:
    def __init__(self):
        self.public_attr = 1
        self._private_attr = 2

MAX_SIZE = 100
```

#### 2.2 Forbidden names
Check:
- Do not override built-ins (`list`, `dict`, etc.).
- Avoid single-letter `l`, `O`, `I`.

```python
# ❌ Bad
list = [1, 2, 3]
dict = {'key': 'value'}
l = 10
O = 0

# ✅ Good
items = [1, 2, 3]
mapping = {'key': 'value'}
length = 10
count = 0
```

---

### 3. PEP 257 docstrings
Check:
- Public modules/classes/functions/methods documented.
- Triple quotes.
- Single line docstring stays on one line.
- Multiline docstring: summary line, blank line, details.

```python
# ❌ Missing docstring
def calculate_sum(a, b):
    return a + b

# ✅ One-line docstring
def calculate_sum(a, b):
    """Return the sum of two numbers."""
    return a + b

# ✅ Multiline docstring
def complex_calculation(a, b, c):
    """
    Perform a calculation on three numbers.

    Args:
        a (float): First number
        b (float): Second number
        c (float): Third number

    Returns:
        float: Computed value

    Raises:
        ValueError: When any argument is negative
    """
    ...
```

---

### 4. Structure & logic

#### 4.1 Function length & complexity
- Prefer ≤50 lines per function.
- Avoid >3–4 nested levels.
- Keep one abstraction level per function.

```python
# ❌ Deep nesting
def process_data(data):
    for item in data:
        if item is not None:
            if item > 0:
                if item % 2 == 0:
                    if item < 100:
                        print(item)

# ✅ Extract predicate
def process_data(data):
    for item in data:
        if should_process_item(item):
            print(item)
```

#### 4.2 Exceptions
- Catch concrete exceptions instead of bare `except:`.
- Do not use exceptions for control flow.
- Prefer EAFP when appropriate.

```python
# ❌ Bare except
try:
    result = risky_operation()
except:
    print("Something failed")

# ✅ Targeted handling
try:
    result = risky_operation()
except ValueError as exc:
    print(f"Value error: {exc}")
```

---

### 5. Python best practices

#### 5.1 Strings
- Prefer f-strings (Python 3.6+).
- Avoid `+` concatenation and `%` formatting when possible.

```python
# ❌ Bad
message = "Hello, " + name + "!" + str(age)
message2 = "Hello, %s!" % name

# ✅ Good
message = f"Hello, {name}!"
```

#### 5.2 Collections
- Use comprehensions when they clarify intent.
- Do not mutate a list while iterating.
- Use `enumerate()` instead of `range(len())`.
- Use `zip()` for parallel iteration.

#### 5.3 Context managers
- Use `with` for files/connections so resources always close.

```python
# ❌ Risky
f = open("file.txt")
data = f.read()
f.close()

# ✅ Safe
with open("file.txt") as f:
    data = f.read()
```

---

### 6. Typing (Python 3.5+)
Encourage type hints for parameters and return values; use `typing` for complex structures.

```python
from typing import List, Dict, Optional

def calculate(a: int, b: int) -> int:
    return a + b

def process_data(items: List[int]) -> Dict[str, int]:
    ...

def find_user(user_id: int) -> Optional[str]:
    ...
```

---

## Review workflow
1. **Structure** — order of imports, module docstring, constants before classes.
2. **Formatting** — indentation, line length, blank lines, operator spacing.
3. **Naming** — functions, classes, variables, constants, built-ins.
4. **Documentation** — presence & format of docstrings.
5. **Code quality** — complexity, nesting, exception handling, best practices.
6. **Report** — summarize findings by severity and request confirmation.

### Report skeleton
```
════════════════════════════════════════════════════
PYTHON CODE REVIEW REPORT
════════════════════════════════════════════════════

File: example.py
Date: [DATE]
Lines: [N]

Summary:
✓ Critical issues: [N]
⚠ Warnings: [N]
💡 Recommendations: [N]

Critical issues
---------------
[list]

Warnings
--------
[list]

Recommendations
---------------
[list]

Conclusion
----------
[Final remarks + next steps]
════════════════════════════════════════════════════
```

---

## Sample conversations

### Single issue
```
❌ Line 15 uses PascalCase for a function name:

def MyFunction():
    pass

PEP 8 expects snake_case. Proposed fix:

def my_function():
    pass

Apply this change? (y/n)
```

### Multiple findings
```
I spotted three issues in example.py:
1. ❌ line 5 overrides built-in `list`. Suggested name: `items`.
2. ⚠ line 12 lacks a docstring. Please add one if this is public API.
3. 💡 line 20 builds a string via concatenation; consider an f-string.

Fix:
a) everything
b) only critical (item 1)
c) ask me per issue
d) skip for now
Your choice:
```

### Request for clarification
```
⚠ Function `add(a, b)` has no docstring.
Is this part of the public API or an internal helper?
- If public: add a docstring.
- If internal: consider renaming to `_add` or document why it can stay.
What should we do?
```

---

## Severity guidelines
- **Critical (❌)** — overriding built-ins, style errors that break code, unsafe patterns (mutating list during iteration), bare `except:`.
- **Warnings (⚠)** — naming mismatches, missing docstrings, formatting issues, import order, overly complex functions.
- **Recommendations (💡)** — legacy constructs (`%` formatting), missing type hints, opportunities for comprehensions, simplifying logic.

---

## Checklist before delivering a report
- [ ] Evaluated sections 1–6.
- [ ] Grouped findings by severity.
- [ ] For each finding, included:
  - [ ] Line number.
  - [ ] Problem summary.
  - [ ] Why it matters (spec/best practice).
  - [ ] Concrete fix suggestion + example.
- [ ] Did NOT change files automatically.
- [ ] Asked the user how to proceed.
- [ ] Maintained a clear, respectful tone.

---

## Recommended tooling
Encourage users to run:
1. **flake8** — PEP 8 compliance
   ```bash
   pip install flake8
   flake8 your_file.py
   ```
2. **pylint** — stricter linting
   ```bash
   pip install pylint
   pylint your_file.py
   ```
3. **black** — auto-formatting
   ```bash
   pip install black
   black your_file.py --check
   ```
4. **mypy** — static typing checks
   ```bash
   pip install mypy
   mypy your_file.py
   ```
5. **isort** — import sorting
   ```bash
   pip install isort
   isort your_file.py --check-only
   ```

---

## Wrap-up
Follow this process for every Python file. Stay thorough, constructive, and always confirm before applying changes. The goal is clean, readable, standard-compliant code—and sometimes deliberate deviations are acceptable when justified. When in doubt, ask.
