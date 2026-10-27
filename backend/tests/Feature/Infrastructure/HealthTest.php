<?php

declare(strict_types=1);

it('answers the health check', function (): void {
    $this->get('/up')->assertOk();
});

it('serves the API under /api', function (): void {
    $this->getJson('/api/ping')->assertOk()->assertExactJson(['status' => 'ok']);
});
