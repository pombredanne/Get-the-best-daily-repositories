<?php
/**
 * @author Aaron Francis <aarondfrancis@gmail.com>
 * @link https://aaronfrancis.com
 * @link https://twitter.com/aarondfrancis
 */

namespace AaronFrancis\Solo\Themes;

use AaronFrancis\Solo\Contracts\Theme;
use Laravel\Prompts\Concerns\Colors;

class LightTheme implements Theme
{
    use Colors {
        dim as baseDim;
    }

    /*
    |--------------------------------------------------------------------------
    | Tabs
    |--------------------------------------------------------------------------
    */
    public function tabFocused(string $text): string
    {
        return $this->bgBlack($this->white($text));
    }

    public function tabBlurred(string $text): string
    {
        return $text;
    }

    public function tabStopped(string $text): string
    {
        $text = trim($text);

        return $this->dim(' ' . $this->strikethrough($text) . ' ');
    }

    public function tabMore(string $text): string
    {
        return $this->dim($text);
    }

    /*
    |--------------------------------------------------------------------------
    | Logs
    |--------------------------------------------------------------------------
    */
    public function logsPaused(string $text): string
    {
        return $this->bgYellow($text);
    }

    public function logsLive(string $text): string
    {
        return $this->dim($text);
    }

    /*
    |--------------------------------------------------------------------------
    | Text
    |--------------------------------------------------------------------------
    */
    public function dim(string $text): string
    {
        return $this->baseDim($text);
    }

    public function exception(string $text): string
    {
        return $this->red($text);
    }

    /*
    |--------------------------------------------------------------------------
    | Process
    |--------------------------------------------------------------------------
    */
    public function processStopped(string $text): string
    {
        return $this->bgRed($this->white($text));
    }

    public function processRunning(string $text): string
    {
        return $this->dim($text);
    }

    /*
    |--------------------------------------------------------------------------
    | Box
    |--------------------------------------------------------------------------
    */
    public function box(): string
    {
        // Provided by https://gist.github.com/flaviut/0db1aec4cadf2ef06455.
        // The top box is the only one that matters. The others are just
        // provided for your convenience. If you want to switch box
        // styles, just move your favorite box to the top.
        return <<<EOT
        ╭─┬─╮
        ├─┼─┤
        │ │ │
        ╰─┴─╯
        ┏━┳━┓
        ┣━╋━┫
        ┃ ┃ ┃
        ┗━┻━┛
        ╔═╦═╗
        ╠═╬═╣
        ║ ║ ║
        ╚═╩═╝
        ┌─┬─┐
        ├─┼─┤
        │ │ │
        └─┴─┘
        EOT;
    }

    public function boxBorder($text): string
    {
        return $this->gray($text);
    }

    public function boxHandle(): string
    {
        return $this->gray('▒');
    }
}
