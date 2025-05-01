## GOALS
- [x] migrate_on
- [x] migrate 
- [x] down-to (move version to n)
- [ ] down (move version by 1)
- [ ] redo (rerun latest migration)
- [ ] reset (drop all migration-based tables)


## TO DO
- [ ] read the version from args
- [ ] read the dir from (args AND env)


## NEEDS TO BE FIXED 
- Need to erase all data from migration_scripts before writing in [FIXED]
- perform drop and perform migrate is different functions (drop maybe not needed at all) [FIXED]

## CONSIDER 
- need i have index of migration scripts in the his own table? (nah)
