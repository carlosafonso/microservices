<?php declare(strict_types = 1);

namespace Afonso\Gcp\Demos\Microservices;

class ApplicationSettings
{
    public function __construct(protected array $settings)
    {
        //
    }

    public function get(string $key)
    {
        if (key_exists($key, $this->settings)) {
            return $this->settings[$key];
        }
        throw new \InvalidArgumentException("Settings key $key does not exist");
    }
}
