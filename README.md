# ddev_setup

Scripts to initialize and reset [DDEV](https://ddev.com) projects with automatic detection.

## ddev-init.sh

Detects project type, docroot, PHP/Node/DB versions, configures DDEV, starts containers, installs dependencies, imports a DB dump if present.

```bash
./ddev-init.sh [--force] [--no-start] [--no-install] [--migrate] [--no-import] \
  [--name NAME] [--php VERSION] [--db TYPE:VER] [--node VERSION] [--docroot PATH]
```

Supported types: Laravel, Symfony, Drupal, TYPO3, Shopware, Magento2, CakePHP, CodeIgniter, CraftCMS, SilverStripe, WordPress, Fat-Free (F3), Node/generic/PHP.

## ddev-reset.sh

Stops and removes the DDEV project (containers + DB) and deletes `.ddev/`.

```bash
./ddev-reset.sh [--force] [--keep-db]
```
