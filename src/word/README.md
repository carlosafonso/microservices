# Word Service

This service returns a random word from a list of words.

It can be configured to leverage a hardcoded list or to look words up in a Cloud Firestore database.

## How to use

```
python -m venv .venv
source .venv/bin/activate
pip install pip-tools
pip-compile && pip-sync
```
