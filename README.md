# ddev_setup

Scripts pour initialiser et réinitialiser des projets [DDEV](https://ddev.com) avec détection automatique.

## ddev-init.sh

Détecte le type de projet, le docroot, les versions PHP/Node/DB, configure DDEV, démarre les conteneurs, installe les dépendances et importe un dump SQL s'il existe.

```bash
./ddev-init.sh [--force] [--no-start] [--no-install] [--migrate] [--no-import] \
  [--name NOM] [--php VERSION] [--db TYPE:VER] [--node VERSION] [--docroot CHEMIN]
```

Types supportés : Laravel, Symfony, Drupal, TYPO3, Shopware, Magento2, CakePHP, CodeIgniter, CraftCMS, SilverStripe, WordPress, Fat-Free (F3), Node/générique/PHP.

## ddev-reset.sh

Arrête et supprime le projet DDEV (conteneurs + base) puis efface `.ddev/`.

```bash
./ddev-reset.sh [--force] [--keep-db]
```
