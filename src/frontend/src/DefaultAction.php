<?php declare(strict_types = 1);

namespace Afonso\Gcp\Demos\Microservices;

use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Google\Cloud\PubSub\PubSubClient;
use League\Plates\Engine;
use Psr\Log\LoggerInterface;

class DefaultAction
{
    public function __construct(
        protected LoggerInterface $log,
        protected Engine $templateEngine,
        protected PubSubClient $pubSub,
        protected ApplicationSettings $settings,
        protected DownstreamServicesClient $client,
        protected EventBus $eventBus,
    )
    {
        //
    }

    public function __invoke(ServerRequestInterface $request, ResponseInterface $response): ResponseInterface
    {
        $env = $this->settings->get('env');

        [$podName, $podIp] = [$this->settings->get('podName'), $this->settings->get('podIp')];

        $word = $color = $size = null;

        try {
            $word = $this->client->getWord();
        } catch (\Exception $e) {
            $this->log->critical('Failed to get word', ['exception' => $e]);
            $word = '(ERROR)';
        }

        try {
            $color = $this->client->getFontColor();
        } catch (\Exception $e) {
            $this->log->critical('Failed to get font color', ['exception' => $e]);
            $color = 'red';
        }

        try {
            $size = $this->client->getFontSize();
        } catch (\Exception $e) {
            $this->log->critical('Failed to get font size', ['exception' => $e]);
            $size = 50;
        }

        $this->log->info("Invoked all services", ['font-color' => $color, 'font-size' => $size, 'word' => $word]);

        if ($this->settings->get('emitToPubSub')) {
            $this->eventBus->sendEvent($color, $size, $word);
            $this->log->info("Sent event to Pub/Sub");
        }

        $response
            ->getBody()
            ->write(
                $this->templateEngine->render(
                    'index',
                    [
                        'color' => $color,
                        'size' => $size,
                        'word' => $word,
                        'env' => $env,
                        'podName' => $podName,
                        'podIp' => $podIp,
                    ]
                )
            );
        return $response;
    }
}
