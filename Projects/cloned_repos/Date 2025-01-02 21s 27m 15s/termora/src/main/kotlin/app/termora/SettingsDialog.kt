package app.termora

import app.termora.db.Database
import java.awt.BorderLayout
import java.awt.Dimension
import java.awt.Window
import java.awt.event.WindowAdapter
import java.awt.event.WindowEvent
import javax.swing.BorderFactory
import javax.swing.JComponent
import javax.swing.JPanel
import javax.swing.UIManager

class SettingsDialog(owner: Window) : DialogWrapper(owner) {
    private val optionsPane = SettingsOptionsPane()
    private val properties get() = Database.instance.properties

    init {
        size = Dimension(UIManager.getInt("Dialog.width"), UIManager.getInt("Dialog.height"))
        isModal = true
        title = I18n.getString("termora.setting")
        setLocationRelativeTo(null)

        init()

        initEvents()
    }

    private fun initEvents() {
        Disposer.register(disposable, object : Disposable {
            override fun dispose() {
                properties.putString("Settings-SelectedOption", optionsPane.getSelectedIndex().toString())
            }
        })

        addWindowListener(object : WindowAdapter() {
            override fun windowActivated(e: WindowEvent) {
                removeWindowListener(this)
                val index = properties.getString("Settings-SelectedOption")?.toIntOrNull() ?: return
                optionsPane.setSelectedIndex(index)
            }
        })
    }

    override fun createCenterPanel(): JComponent {
        optionsPane.background = UIManager.getColor("window")

        val panel = JPanel(BorderLayout())
        panel.add(optionsPane, BorderLayout.CENTER)
        panel.background = UIManager.getColor("window")
        panel.border = BorderFactory.createMatteBorder(1, 0, 0, 0, DynamicColor.BorderColor)

        return panel
    }

    override fun createSouthPanel(): JComponent? {
        return null
    }


}