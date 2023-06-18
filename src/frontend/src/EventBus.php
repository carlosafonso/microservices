<?php declare(strict_types = 1);

namespace Afonso\Gcp\Demos\Microservices;

use Google\Cloud\PubSub\PubSubClient;

class EventBus
{
    public function __construct(
        protected string $pubSubEventsTopic,
        protected PubSubClient $pubSub
    )
    {
        //
    }

    public function sendEvent(string $fontColor, int $fontSize, string $word)
    {
        $topic = $this->pubSub->topic($this->pubSubEventsTopic);

        // Publish an event into the Pub/Sub events topic.
        $eventPayload = [
            'word' => $word,
            'color' => $fontColor,
            'size' => $fontSize,
        ];
        $topic->publish(['data' => json_encode($eventPayload)]);
    }
}
