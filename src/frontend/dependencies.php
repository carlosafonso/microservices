<?php declare(strict_types = 1);

use Afonso\Gcp\Demos\Microservices\ApplicationSettings;
use Afonso\Gcp\Demos\Microservices\DownstreamServicesClient;
use Afonso\Gcp\Demos\Microservices\EventBus;
use Afonso\Gcp\Demos\Microservices\HttpClient;
use DI\ContainerBuilder;
use Google\Cloud\PubSub\PubSubClient;
use League\Plates\Engine;
use Monolog\Handler\StreamHandler;
use Monolog\Logger;
use Psr\Container\ContainerInterface;
use Psr\Log\LoggerInterface;

return function(ContainerBuilder $containerBuilder) {
    $containerBuilder->addDefinitions([
        LoggerInterface::class => function (ContainerInterface $c) {
            $logger = new Logger('frontend');
            $logger->pushHandler(new StreamHandler('php://stdout'));
            return $logger;
        },

        ApplicationSettings::class => function (ContainerInterface $c) {
            $pubSubEventsTopic = getenv('PUBSUB_EVENTS_TOPIC');

            $settings = [
                // Application environment.
                'env' => getenv('MICROSERVICES_ENV') ?: 'dev',
                // Pod metadata.
                'podName' => getenv('MSVC_POD_NAME'),
                'podIp' => getenv('MSVC_POD_IP'),
                // Downstream services endpoints.
                'fontColorSvcEndpoint' => getenv('FONT_COLOR_SVC'),
                'fontSizeSvcEndpoint' => getenv('FONT_SIZE_SVC'),
                'wordSvcEndpoint' => getenv('WORD_SVC'),
                // Pub/Sub configuration.
                'pubSubEventsTopic' => $pubSubEventsTopic ?: '',
                'emitToPubSub' => $pubSubEventsTopic !== false && !empty($pubSubEventsTopic),
            ];

            // Log settings for debug purposes.
            $c->get(LoggerInterface::class)->info("Settings:", $settings);

            return new ApplicationSettings($settings);
        },

        Engine::class => function (ContainerInterface $c) {
            return new Engine(__DIR__ . '/templates');
        },

        PubSubClient::class => function (ContainerInterface $c) {
            return new PubSubClient();
        },

        HttpClient::class => function (ContainerInterface $c) {
            return new HttpClient(timeout: 1);
        },

        DownstreamServicesClient::class => function (ContainerInterface $c) {
            $settings = $c->get(ApplicationSettings::class);
            $client = new DownstreamServicesClient(
                $c->get(HttpClient::class),
                $settings->get('fontColorSvcEndpoint'),
                $settings->get('fontSizeSvcEndpoint'),
                $settings->get('wordSvcEndpoint'),
            );
            return $client;
        },

        EventBus::class => function (ContainerInterface $c) {
            $settings = $c->get(ApplicationSettings::class);
            return new EventBus(
                $settings->get('pubSubEventsTopic'),
                $c->get(PubSubClient::class)
            );
        },
    ]);
};
