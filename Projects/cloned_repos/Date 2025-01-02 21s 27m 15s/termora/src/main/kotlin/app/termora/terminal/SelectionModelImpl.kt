package app.termora.terminal

import java.util.*
import kotlin.math.max
import kotlin.math.min

open class SelectionModelImpl(private val terminal: Terminal) : SelectionModel {
    private var startPosition = Position.unknown
    private var endPosition = Position.unknown
    private val document = terminal.getDocument()

    internal companion object {
        fun isPointInsideArea(start: Position, end: Position, x: Int, y: Int, cols: Int): Boolean {
            val top = min(start.y, end.y)
            val bottom = max(start.y, end.y)

            if (y in top..bottom) {
                if (start.y == end.y) {
                    val left = min(start.x, end.x)
                    val right = max(start.x, end.x)
                    return x in left..right
                } else if (y == start.y) {
                    return x >= start.x && x <= cols
                } else if (y == end.y) {
                    return x >= 0 && x <= end.x
                } else {
                    return x in 0..cols
                }
            }

            return false
        }
    }

    override fun getSelectedText(): String {
        val sb = StringBuilder()

        if (!hasSelection()) {
            return sb.toString()
        }

        val iterator = getChars(getSelectionStartPosition(), getSelectionEndPosition())
        while (iterator.hasNext()) {
            val line = iterator.next()
            val chars = line.chars()
            if (chars.isEmpty() || chars.first().first.isNull) {
                continue
            }

            for (e in chars) {
                if (e.first.isSoftHyphen) {
                    continue
                } else if (e.first.isNull) {
                    break
                }
                sb.append(e.first)
            }

            if (line.wrapped) {
                continue
            }

            if (iterator.hasNext()) {
                sb.appendLine()
            }
        }

        if (sb.isNotEmpty() && sb.last() == ControlCharacters.LF) {
            sb.deleteCharAt(sb.length - 1)
        }

        return sb.toString()
    }

    private fun getChars(startPosition: Position, endPosition: Position): Iterator<TerminalLine> {

        if (!startPosition.isValid() || !endPosition.isValid()) {
            return Collections.emptyIterator()
        }

        val cols = terminal.getTerminalModel().getCols()
        val document = terminal.getDocument()

        return object : Iterator<TerminalLine> {
            private var index = startPosition.y

            override fun hasNext(): Boolean {
                return index <= endPosition.y && index <= document.getLineCount()
            }

            override fun next(): TerminalLine {
                val current = document.getLine(index)
                val line = when (index) {
                    startPosition.y -> {
                        val endCols = if (startPosition.y == endPosition.y) endPosition.x else cols
                        val offset = startPosition.x - 1
                        val chars = current.chars()
                        val count = chars.size
                        TerminalLine(
                            chars.subList(
                                offset,
                                min(endCols, count)
                            )
                        ).apply {
                            wrapped = hasNext() && current.wrapped
                        }
                    }

                    endPosition.y -> {
                        val chars = current.chars()
                        val count = chars.size
                        if (endPosition.x == count) {
                            current
                        } else {
                            TerminalLine(chars.subList(0, min(endPosition.x, count)))
                        }
                    }

                    else -> {
                        current
                    }
                }

                index++

                return line
            }

        }

    }

    override fun setSelection(startPosition: Position, endPosition: Position) {

        if (startPosition.y > endPosition.y || (startPosition.y == endPosition.y && endPosition.x <
                    startPosition.x)
        ) {
            throw IllegalArgumentException("Position out of range")
        }

        this.startPosition = startPosition
        this.endPosition = endPosition
        fireSelectionChanged()
    }

    override fun getSelectionStartPosition(): Position {
        return startPosition
    }

    override fun getSelectionEndPosition(): Position {
        return endPosition
    }

    override fun clearSelection() {
        this.startPosition = Position.unknown
        this.endPosition = Position.unknown
        fireSelectionChanged()
    }

    protected fun fireSelectionChanged() {
        terminal.getTerminalModel().setData(SelectionModel.Selection, Unit)
    }

    override fun getTerminal(): Terminal {
        return terminal
    }

    override fun hasSelection(): Boolean {
        return startPosition.isValid() && endPosition.isValid()
    }

    override fun hasSelection(position: Position): Boolean {
        return hasSelection(position.x, position.y)
    }

    override fun hasSelection(x: Int, y: Int): Boolean {
        return hasSelection() && isPointInsideArea(
            startPosition,
            endPosition,
            x,
            y,
            terminal.getTerminalModel().getCols()
        )
    }


}