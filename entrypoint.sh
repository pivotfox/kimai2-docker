#!/bin/bash

set +x
set -e
set -o errexit
set -o pipefail

echo "Kimai $KIMAI entrypoint"

function installPlugin() {
    local PLUGIN=$1
    local PLUGINUC=${PLUGIN^^}
    local ENABLED="INSTALL_PLUGIN_$PLUGINUC"

    if [ "${!ENABLED}" != "true" ]; then
      echo "Skipping Plugin $PLUGIN..."
      return
    fi

    if ! [ -d "/home/project/kimai2/var/plugins/$PLUGIN" ]; then

      if [ -d "/opt/kimai2/plugins/$PLUGIN" ]; then
        echo "Installing plugin: $PLUGIN"
        mv "/opt/kimai2/plugins/$PLUGIN" /home/project/kimai2/var/plugins/
      else
        echo "Warning: plugin $PLUGIN not found!?"
      fi

      if [ "$PLUGIN" = "ReadOnlyAccessBundle" ]; then
        touch /home/project/kimai2/templates/macros/actions.html.twig
        chown project:project /home/project/kimai2/templates/macros/actions.html.twig
      fi

    else
      echo "Warning: plugin $PLUGIN already installed"
    fi
}

function initialize() {
    if [ -n "$TZ" ]; then
      echo "Setting timezone to $TZ"
      echo "$TZ" > /etc/TZ
      ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
    else
      echo "Timezone is set to $(cat /etc/TZ)"
    fi

    if ! [ -e /home/project/kimai2/var/data/version ]; then 
      echo "Installing Kimai2..."
      su -c "/home/project/kimai2/bin/console -n kimai:install" project
      if [ -n "$INSTALL_ADMINUSER" ] && [ -n "$INSTALL_ADMINPASS" ] && [ -n "$INSTALL_ADMINMAIL" ]; then
        echo "Creating superuser..."
        su -c "/home/project/kimai2/bin/console kimai:create-user $INSTALL_ADMINUSER $INSTALL_ADMINMAIL ROLE_SUPER_ADMIN $INSTALL_ADMINPASS" project
      else
        echo "Skipping superuser creation..."
      fi
      echo "$KIMAI" > /home/project/kimai2/var/data/version
      chown -R project:project /home/project/kimai2/var/
    else
      # @todo compare versions, afterwards to update when necessary
      su -c "bin/console kimai:update" project
    fi

    installPlugin "EasyBackupBundle"
    installPlugin "CustomCSSBundle"
    installPlugin "ReadOnlyAccessBundle"
    installPlugin "RecalculateRatesBundle"
    installPlugin "EmptyDescriptionCheckerBundle"

    if [ "$ALLOW_USER_REG" = "true" ]; then
      yq w -i config/packages/local.yaml kimai.user.registration true
    else
      yq w -i config/packages/local.yaml kimai.user.registration false
    fi

    su -c "bin/console cache:clear" project
    su -c "bin/console cache:warmup" project
    su -c "bin/console doctrine:migrations:status" project
    echo "Kimai2 ready..."
}

case "${1-}" in
    'bash')
        exec /bin/bash;
        ;;
    'web')
        initialize
        exec supervisord;
        ;;
    *)
        exec /bin/sh -c "$@";
        ;;
esac

