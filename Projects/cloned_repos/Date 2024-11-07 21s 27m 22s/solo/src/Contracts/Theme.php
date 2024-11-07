<?php
/**
 * @author Aaron Francis <aarondfrancis@gmail.com>
 * @link https://aaronfrancis.com
 * @link https://twitter.com/aarondfrancis
 */

namespace AaronFrancis\Solo\Contracts;

interface Theme
{
    /*
    |--------------------------------------------------------------------------
    | Tabs
    |--------------------------------------------------------------------------
    */
    public function tabFocused(string $text): string;

    public function tabBlurred(string $text): string;

    public function tabStopped(string $text): string;

    public function tabMore(string $text): string;

    /*
    |--------------------------------------------------------------------------
    | Logs
    |--------------------------------------------------------------------------
    */
    public function logsPaused(string $text): string;

    public function logsLive(string $text): string;

    /*
    |--------------------------------------------------------------------------
    | Text
    |--------------------------------------------------------------------------
    */
    public function dim(string $text): string;

    public function exception(string $text): string;

    /*
    |--------------------------------------------------------------------------
    | Process
    |--------------------------------------------------------------------------
    */
    public function processStopped(string $text): string;

    public function processRunning(string $text): string;

    /*
    |--------------------------------------------------------------------------
    | Box
    |--------------------------------------------------------------------------
    */
    public function box(): string;

    public function boxBorder(string $text): string;

    public function boxHandle(): string;
}
