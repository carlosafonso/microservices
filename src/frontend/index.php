<?php declare(strict_types = 1);

require __DIR__ . '/vendor/autoload.php';

use Afonso\Gcp\Demos\Microservices\DefaultAction;
use DI\ContainerBuilder;
use Slim\Factory\AppFactory;

$containerBuilder = new ContainerBuilder();

$registerDependencies = require(__DIR__ . '/dependencies.php');
$registerDependencies($containerBuilder);

$app = AppFactory::createFromContainer($containerBuilder->build());

$app->get('/', DefaultAction::class);

$app->run();
