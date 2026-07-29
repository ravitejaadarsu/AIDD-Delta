---
description: Install/refresh AIDD in this repo, then run the Master interview if needed
---

Run the AIDD installer for this repository: execute `bash` on the installer from the AIDD-Delta checkout (or ask the user for its path if unknown), i.e. `AIDD_SRC=<checkout> <checkout>/install.sh`. Then, if `.aidd/state.yaml` reports `constitution: missing`, read `.aidd/framework/playbooks/10-master.md` and execute it exactly.
