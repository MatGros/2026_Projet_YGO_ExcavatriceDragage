# TwinBench

## Start here

Double-click [`00_START.cmd`](00_START.cmd).

```text
00_START.cmd       Master menu
├─ 10_PROJECT.cmd  Select / prepare the isolated Control Win project copy
└─ 20_SIM.cmd      Run the local M3 simulation
```

## Folders

| Folder | Contents |
|---|---|
| `01_PROJECT/` | Control Win project copy, preparation and deployment tools |
| `02_SIM/` | OpenModelica model and local FMU/QML simulator |
| `03_TRANSPORT/` | Native UDP transport benchmark (T408) |
| `90_PROTOTYPES/` | Experimental PLC-linked M3 tools, not part of the normal workflow |

The local M3 simulation is separate from the Control Win project. The PLC-linked M3 prototype
under `90_PROTOTYPES/` has not passed the integrated acceptance needed to be presented as a
reliable simulator workflow.

Technical scripts and tests stay inside their owning folder. The root is reserved for the master
launcher and its two direct actions.
