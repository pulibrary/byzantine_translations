## Local development with Lando

1. `git clone git@github.com:pulibrary/byzantine_translations.git`
1. `cp sites/default/default.settings.php sites/default/settings.php`
1. In your local `sites/default/settings.php` file include the following lando-style db config values:

    ```
    $databases = array (
      'default' =>
      array (
        'default' =>
        array (
          'database' => 'drupal7',
          'username' => 'drupal7',
          'password' => 'drupal7',
          'host' => 'database',
          'port' => '3306',
          'driver' => 'mysql',
          'prefix' => '',
        ),
      ),
    );
    # needed for CAS logins to work
    $base_url = "http://byzantine.lndo.site";
    ```
1. Add the following useful local development configuration to the end of `sites/default/settings.php`
    ```
    /* Overrides for the local environment */
    $conf['securepages_enable'] = 0;
    /* This should be set in your php.ini file */
    ini_set('memory_limit', '1G');
    /* Turn off all caching */
    $conf['css_gzip_compression'] = FALSE;
    $conf['js_gzip_compression'] = FALSE;
    $conf['cache'] = 0;
    $conf['block_cache'] = 0;
    $conf['preprocess_css'] = 0;
    $conf['preprocess_js'] = 0;
    /* end cache settings */
    /* Turn on theme debugging. Injects the path to every Template utilized in the HTML source. */
    $conf['theme_debug'] = TRUE;

    /* Makes sure jquery is loaded on every page */
    /* set to false in production */
    $conf['javascript_always_use_jquery'] = TRUE;
    ```
1. `mkdir .ssh` # excluded from version control
1. `cp $HOME/.ssh/id_rsa .ssh/.`
1. `cp $HOME/.ssh/id_rsa.pub .ssh/.` // key should be registered in princeton_ansible deploy role
1. `lando start`
1. `cp drush/byzantine-example.aliases.drushrc.php drush/byzantine.aliases.drushrc.php`
1. Adjust the config values in the  `drush/byzantine.aliases.drushrc.php` file to match the current remote drupal environment
    ```
    $aliases['prod'] = array (
      'uri' => 'https://library.princeton.edu/byzantine',
      'root' => '', // Add root
      'remote-user' => 'drupal', // Add user
      'remote-host' => 'app-server-name', // Add app server host name
      'ssh-options' => '-o PasswordAuthentication=no -i .ssh/id_rsa',
      'path-aliases' => array(
        '%dump-dir' => '/tmp',
      ),
      'source-command-specific' => array (
        'sql-sync' => array (
          'no-cache' => TRUE,
          'structure-tables-key' => 'common',
        ),
      ),
      'command-specific' => array (
        'sql-sync' => array (
          'sanitize' => TRUE,
          'no-ordered-dump' => TRUE,
          'structure-tables' => array(
            // You can add more tables which contain data to be ignored by the database dump
            'common' => array('cache', 'cache_*', 'history', 'sessions', 'watchdog', 'cas_data_login', 'captcha_sessions'),
          ),
        ),
      ),
    );
    ```
1. Uncomment the alias block for the local lando site
    ```
    $aliases['local'] = array(
      'root' => '/app', // Path to project on local machine
      'uri'  => 'http://byzantine.lndo.site',
      'path-aliases' => array(
        '%dump-dir' => '/tmp',
        '%files' => 'sites/default/files',
      ),
    );
    ```
1. `lando drush @byzantine.prod sql-dump --structure-tables-list='watchdog,sessions,cas_data_login,history,captcha_sessions,cache,cache_*' --result-file=/tmp/dump.sql; scp pulsys@libraryphp:/tmp/dump.sql .` // Change @libraryphp based on your ssh alias
1. `lando db-import dump.sql`
1. `lando drush rsync @byzantine.prod:%files @byzantine.local:%files`
1. `lando drush uli your-username`
1. `mkdir byzantine; cd byzantine; ln -s ../sites .; cd ..` 

### .htaccess rewrite base
1. edit .htaccess and comment out `RewriteBase /byzantine` and uncomment `RewriteBase /`

### Solr / Search API

1. In your browser, go to `http://byzantine.lndo.site/admin/config/search/apachesolr/settings/solr/edit?destination=admin/config/search/apachesolr/settings`
1. Edit **Solr url** to have the value of `http://search:8983/solr/byzantine`
1. Go to `http://byzantine.lndo.site/admin/config/search/apachesolr/settings/solr/index` and clikc index all
1. `lando drush cc all` will update the caches to show the data

### Testing
  
  Install the percy key locally
  1. `cp percy.env.example to percy.env`
  1. edit the file and put in the key from https://percy.io/Princeton-University-Library/byzantine/settings

  To run the visual tests and send snapshots to percy.io
  1. `lando test`
  You will get a resultant build url, which you can use to see what has changed. Be aware the order of the result list seems to be random, so some changes there is to be expected.

### Deploying
Deployment is through capistrano. To deploy a branch other than "main", prepend an environment variable to your deploy command, e.g.:
`BRANCH=my_feature bundle exec cap staging deploy`
