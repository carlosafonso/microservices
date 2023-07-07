<?php

namespace Afonso\Gcp\Demos\Microservices;

use Google\Auth\ApplicationDefaultCredentials;
use GuzzleHttp\Client;
use GuzzleHttp\HandlerStack;
use GuzzleHttp\Psr7\Request;

class HttpClient
{
    /**
     * @param $timeout The max request timeout in seconds.
     */
    public function __construct(protected int $timeout) {}

    /**
     * Make an HTTP GET request to the given URL, signing the request in the
     * process if the URL happens to be a Cloud Run service.
     */
    public function get($url)
    {
        $client = null;
        if (strpos($url, '.a.run.app') !== false) {
            // URL is a Cloud Run service. Use an HTTP client that
            // automatically signs the URL so that requests to Cloud Run are
            // authorized.
            //
            // We can use the URL as the audience for now, because the
            // audience should be the root URL of the Cloud Run service we are
            // invoking, which holds true for the time being.
            $middleware = ApplicationDefaultCredentials::getIdTokenMiddleware($url);
            $stack = HandlerStack::create();
            $stack->push($middleware);

            $client = new Client([
                'handler' => $stack,
                'auth' => 'google_auth',
                'timeout' => $this->timeout,
            ]);
        } else {
            // URL is NOT a Cloud Run service. Use a generic HTTP client.
            $client = new Client(['timeout' => $this->timeout]);
        }

        // `$client->get()` does not trigger the automatic PSR-18 OpenTelemetry
        // instrumentation, hence the need to create a new Request().
        return $client->sendRequest(new Request('GET', $url))->getBody();
    }
}
