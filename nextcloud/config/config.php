<?php
/**
 * Nextcloud конфигурация для интеграции с OnlyOffice и Zitadel OIDC.
 */

$CONFIG = array (
  'trusted_proxies' => ['172.16.0.0/12'],
  'overwriteprotocol' => 'http',
  'datadirectory' => '/var/www/html/data',

  // OnlyOffice integration
  'onlyoffice' => array(
    'verify_peer_off' => true,
  ),

  // OIDC авторизация через Zitadel
  'oidc_login' => array(
    'oidc_endpoint' => 'http://zitadel:9200',
    'client_id' => getenv('NC_ZITADEL_CLIENT_ID') ?: 'placeholder',
    'client_secret' => getenv('NC_ZITADEL_CLIENT_SECRET') ?: 'placeholder',
    'auto_provision' => true,
    'auto_login' => true,
  ),

  // Безопасность
  'default_phone_region' => 'RU',
  'loglevel' => 2,
  'maintenance_window_start' => 1,
);
