<?php

declare(strict_types=1);

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// Temporary smoke route; replaced by module routes in step 2.
Route::get('/ping', fn () => ['status' => 'ok']);

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');
