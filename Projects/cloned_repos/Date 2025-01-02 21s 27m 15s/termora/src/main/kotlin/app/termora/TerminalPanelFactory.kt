package app.termora

import app.termora.highlight.KeywordHighlightPaintListener
import app.termora.terminal.PtyConnector
import app.termora.terminal.Terminal
import app.termora.terminal.panel.TerminalHyperlinkPaintListener
import app.termora.terminal.panel.TerminalPanel
import java.awt.event.ComponentEvent
import java.awt.event.ComponentListener
import javax.swing.SwingUtilities

class TerminalPanelFactory {
    private val terminalPanels = mutableListOf<TerminalPanel>()

    companion object {
        val instance by lazy { TerminalPanelFactory() }
    }

    fun createTerminalPanel(terminal: Terminal, ptyConnector: PtyConnector): TerminalPanel {
        val terminalPanel = TerminalPanel(terminal, ptyConnector)
        terminalPanel.addTerminalPaintListener(MultipleTerminalListener())
        terminalPanel.addTerminalPaintListener(KeywordHighlightPaintListener.instance)
        terminalPanel.addTerminalPaintListener(TerminalHyperlinkPaintListener.instance)
        terminalPanels.add(terminalPanel)
        return terminalPanel
    }

    fun getTerminalPanels(): List<TerminalPanel> {
        return terminalPanels
    }

    fun repaintAll() {
        if (SwingUtilities.isEventDispatchThread()) {
            terminalPanels.forEach { it.repaintImmediate() }
        } else {
            SwingUtilities.invokeLater { repaintAll() }
        }
    }

    fun fireResize() {
        getTerminalPanels().forEach { c ->
            c.getListeners(ComponentListener::class.java).forEach {
                it.componentResized(ComponentEvent(c, ComponentEvent.COMPONENT_RESIZED))
            }
        }
    }

}