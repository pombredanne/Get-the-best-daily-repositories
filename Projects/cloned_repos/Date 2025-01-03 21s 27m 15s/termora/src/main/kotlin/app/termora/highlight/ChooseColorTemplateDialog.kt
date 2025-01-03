package app.termora.highlight

import app.termora.DialogWrapper
import app.termora.TerminalFactory
import com.formdev.flatlaf.util.SystemInfo
import java.awt.*
import java.awt.event.MouseAdapter
import java.awt.event.MouseEvent
import javax.swing.*

class ChooseColorTemplateDialog(owner: Window, title: String) : DialogWrapper(owner) {

    var color: Color? = null
        private set
    var colorIndex = -1
    var defaultColor: Color = Color.white

    init {
        size = Dimension(UIManager.getInt("Dialog.width"), UIManager.getInt("Dialog.height"))
        isModal = true
        super.setTitle(title)
        controlsVisible = false
        isResizable = false

        init()
        pack()
        setLocationRelativeTo(null)

    }

    override fun createCenterPanel(): JComponent {
        val panel = JPanel(GridLayout(2, 8, 4, 4))
        val colorPalette = TerminalFactory.instance.createTerminal().getTerminalModel().getColorPalette()
        for (i in 1..16) {
            val c = JPanel()
            c.preferredSize = Dimension(24, 24)
            c.background = Color(colorPalette.getXTerm256Color(i))
            c.addMouseListener(object : MouseAdapter() {
                override fun mouseClicked(e: MouseEvent) {
                    if (SwingUtilities.isLeftMouseButton(e)) {
                        color = c.background
                        colorIndex = i
                        doOKAction()
                    }
                }
            })
            panel.add(c)
        }
        panel.border = BorderFactory.createEmptyBorder(0, 0, 12, 0)
        val customBtn = JButton("Custom")
        customBtn.addActionListener {
            val dialog = MyColorPickerDialog(this)
            dialog.colorPicker.color = defaultColor
            dialog.isVisible = true
            val color = dialog.color
            if (color != null) {
                this.color = color
                this.colorIndex = -1
                doOKAction()
            }
        }
        customBtn.isFocusable = false

        val cPanel = JPanel(BorderLayout())
        cPanel.add(panel, BorderLayout.CENTER)
        cPanel.add(customBtn, BorderLayout.SOUTH)
        cPanel.border = BorderFactory.createEmptyBorder(if (SystemInfo.isLinux) 6 else 0, 12, 12, 12)
        return cPanel
    }


    override fun createSouthPanel(): JComponent? {
        return null
    }
}