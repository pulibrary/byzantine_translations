# config valid for current version and patch releases of Capistrano
lock '~> 3.0'

set :application, 'byzantine'
set :repo_url, 'https://github.com/pulibrary/byzantine_translations.git'
# Default branch is :main
set :branch, ENV['BRANCH'] || 'main'

set :keep_releases, 5
set :deploy_to, '/var/www/byzantine'

set :drupal_settings, '/home/deploy/settings.php'
set :drupal_site, 'default'
set :drupal_file_temporary_path, '../../shared/tmp'
set :drupal_file_public_path, 'sites/default/files'

# Default value for :linked_files is []
append :linked_files, "#{fetch(:drupal_file_public_path)}/favicon_0_0.ico",
       "#{fetch(:drupal_file_public_path)}/firestone-small.png", "#{fetch(:drupal_file_public_path)}/hp_logo.jpg", "#{fetch(:drupal_file_public_path)}/pul-logo.gif"

set :cas_cert_location, '/etc/ssl/certs/ssl-cert-snakeoil.pem'

set :user, 'deploy'

namespace :drupal do
  desc 'Include creation of additional Drupal specific shared folders'
  task :prepare_shared_paths do
    on release_roles :app do
      execute :mkdir, '-p', "#{shared_path}/tmp"
      execute :sudo, "/bin/chown -R www-data #{shared_path}/tmp"
    end
  end

  desc 'Link settings.php'
  task :link_settings do
    on roles(:app) do |_host|
      execute "cd #{release_path}/sites/#{fetch(:drupal_site)} && cp #{fetch(:drupal_settings)} settings.php"
      info "linked settings into #{release_path}/sites/#{fetch(:drupal_site)} site"
    end
  end

  # desc "Link shared drupal files"
  # task :link_files do
  #   on roles(:app) do |host|
  #     execute "cd #{release_path}/sites/all/themes/byzantine_translations_theme"
  #     info "linked files mount into #{fetch(:drupal_site)} site"
  #   end
  # end

  desc 'Clear the drupal cache'
  task :cache_clear do
    on release_roles :drupal_primary do
      execute "sudo -u www-data /usr/local/bin/drush -r #{release_path} cc all"
      info 'cleared the drupal cache'
    end
  end

  desc 'Update file permissions to follow best security practice: https://drupal.org/node/244924'
  task :set_permissions_for_runtime do
    on release_roles :app do
      execute :find, release_path.to_s, '-type f -exec', :chmod, "640 {} ';'"
      execute :find, release_path.to_s, '-type d -exec', :chmod, "2750 {} ';'"
      execute :find, "#{shared_path}/tmp", '-type d -exec', :chmod, "2770 {} ';'"
    end
  end

  desc 'Set the site offline'
  task :site_offline do
    on release_roles :app do
      execute "drush -r #{release_path} vset --exact maintenance_mode 1; true"
      info 'set site to offline'
    end
  end

  desc 'Set the site online'
  task :site_online do
    on release_roles :app do
      execute "drush -r #{release_path} vdel -y --exact maintenance_mode"
      info 'set site to online'
    end
  end

  desc 'Set file system variables'
  task :set_file_system_variables do
    on release_roles :app do
      execute "drush -r #{release_path} vset --exact file_temporary_path #{fetch(:drupal_file_temporary_path)}"
      execute "drush -r #{release_path} vset --exact file_public_path #{fetch(:drupal_file_public_path)}"
    end
  end

  desc 'change the owner of the directory to www-data for apache'
  task :update_directory_owner do
    on release_roles :app do
      execute :sudo, "/bin/chown -R www-data #{release_path}"
      deploy_directory = capture "ls #{deploy_to}"
      execute :sudo, "/bin/chown -R www-data #{deploy_to}/current/" if deploy_directory.include?('current')
    end
  end

  desc 'change the owner of the directory to deploy'
  task :update_directory_owner_deploy do
    on release_roles :app do
      ls_results = capture "ls #{fetch(:deploy_to)}"
      release_paths = if ls_results.include?('current')
                        current_release_path = capture "readlink #{fetch(:deploy_to)}/current"
                        current_release = current_release_path.split('/').last
                        info current_release
                        ls_results = capture "ls #{fetch(:deploy_to)}/releases/"
                        ls_results.split(ls_results[14])
                      else
                        ['']
                      end
      release_paths.each do |release|
        next if release == current_release

        execute :sudo, "/bin/chown -R deploy #{fetch(:deploy_to)}/releases/#{release}"
        execute :chmod, "-R u+w #{fetch(:deploy_to)}/releases/#{release}"
      end
    end
  end

  desc 'change the owner of the directory to www-data for apache'
  task :restart_apache2 do
    on release_roles :drupal_primary do
      info 'starting restart on primary'
      execute :sudo, '/usr/sbin/service apache2 restart'
      info 'completed restart on primary'
    end
    on release_roles :drupal_secondary do
      info 'starting restart on secondary'
      execute :sudo, '/usr/sbin/service apache2 restart'
      info 'completed restart on secondary'
    end
  end

  desc 'Stop the apache2 process'
  task :stop_apache2 do
    on release_roles :app do
      execute :sudo, '/usr/sbin/service apache2 stop'
    end
  end

  desc 'Start the apache2 process'
  task :start_apache2 do
    on release_roles :app do
      execute :sudo, '/usr/sbin/service apache2 start'
    end
  end

  namespace :database do
    task :upload_and_import do
      on release_roles :drupal_primary do
        gz_file_name = ENV['SQL_GZ']
        sql_file_name = gz_file_name.sub('.gz', '')
        upload! File.join(ENV['SQL_DIR'], gz_file_name), "/tmp/#{gz_file_name}"
        execute "gzip -f -d /tmp/#{gz_file_name}"
        execute "drush -r #{release_path} sql-cli < /tmp/#{sql_file_name}"
      end
    end

    desc 'Upload the dump file and import it SQL_DIR/SQL_GZ'
    task :import_dump do
      invoke 'drupal:site_offline'
      invoke 'drupal:database:upload_and_import'
      invoke 'drupal:database:update_db_variables'
      invoke 'drupal:site_online'
      invoke 'drupal:database:clear_search_index'
      invoke 'drupal:database:update_search_index'
    end

    desc 'Update variables on a dump import'
    task :update_db_variables do
      on release_roles :drupal_primary do
        execute "drush -r #{release_path} vset --exact cas_cert #{fetch(:cas_cert_location)}"
      end
    end

    desc 'Update the drupal database'
    task :update do
      on release_roles :drupal_primary do
        execute "sudo -u www-data /usr/local/bin/drush -r #{release_path} -y updatedb"
      end
    end
  end
end

namespace :deploy do
  desc 'Set file system variables'
  task :after_deploy_check do
    invoke 'drupal:prepare_shared_paths'
  end

  desc 'Set file system variables'
  task :after_deploy_updated do
    invoke 'drupal:link_settings'
    # invoke "drupal:link_files"
    invoke 'drupal:database:upload_and_import' unless ENV['SQL_GZ'].nil?
    invoke 'drupal:set_permissions_for_runtime'
    invoke 'drupal:set_file_system_variables'
    invoke 'drupal:update_directory_owner'
  end

  desc 'stop apache before realease'
  task :before_release do
    invoke 'drupal:stop_apache2'
  end

  desc 'Reset directory permissions and Restart apache'
  task :after_release do
    invoke! 'drupal:update_directory_owner'
    invoke 'drupal:start_apache2'
    invoke 'drupal:cache_clear'
    invoke 'drupal:database:update'
    invoke! 'drupal:cache_clear'
  end

  before 'symlink:release', 'deploy:before_release'

  after :check, 'deploy:after_deploy_check'

  # after :started, "drupal:site_offline"

  after :updated, 'deploy:after_deploy_updated'

  before :finishing, 'drupal:update_directory_owner_deploy'
  after 'symlink:release', 'deploy:after_release'
end

desc 'Database dump'
task :database_dump do
  date = Time.now.strftime('%Y-%m-%d')
  file_name = "backup-#{date}-#{fetch(:stage)}"
  on release_roles :app do
    execute "mysqldump #{fetch(:db_name)} > /tmp/#{file_name}.sql"
    execute "gzip -f /tmp/#{file_name}.sql"
    download! "/tmp/#{file_name}.sql.gz", "#{file_name}.sql.gz"
  end
end
