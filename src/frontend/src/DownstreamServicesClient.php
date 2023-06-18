<?php declare(strict_types = 1);

namespace Afonso\Gcp\Demos\Microservices;

class DownstreamServicesClient
{
    public function __construct(
        protected HttpClient $httpClient,
        protected string $fontColorSvcEndpoint,
        protected string $fontSizeSvcEndpoint,
        protected string $wordSvcEndpoint,
    )
    {
        //
    }

    public function getFontColor(): string
    {
        $response = $this->httpClient->get($this->fontColorSvcEndpoint);
        return json_decode((string) $response)->color;
    }

    public function getFontSize(): int
    {
        $response = $this->httpClient->get($this->fontSizeSvcEndpoint);
        return json_decode((string) $response)->size;
    }

    public function getWord(): string
    {
        $response = $this->httpClient->get($this->wordSvcEndpoint);
        return json_decode((string) $response)->word;
    }
}
