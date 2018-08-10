package com.sirolf2009.zkeditor.editor.json

import javafx.scene.layout.Priority
import javafx.scene.layout.VBox
import javafx.scene.web.WebView
import netscape.javascript.JSObject
import com.sirolf2009.zkeditor.IEditor

class JSonEditor extends VBox implements IEditor {

	val WebView webView

	new() {
		webView = new WebView()
		getEngine().load(JSonEditor.getResource("/jsoneditor/json-editor.html").toExternalForm())
		getChildren().add(webView)
		VBox.setVgrow(webView, Priority.ALWAYS)
	}
	
	override getText() {
		getEditor().call("getText") as String
	}
	
	override setText(String text) {
		try {
			getEditor().call("setText", text)
		} catch(Exception e) {
			setMode(Mode.CODE)
			setText(text)
		}
	}
	
	def setMode(Mode mode) {
		getEditor().call("setMode", mode.toString().toLowerCase())
	}
	
	def getMode(Mode mode) {
		Mode.valueOf((getEditor().call("getMode") as String).toUpperCase())
	}
	
	def getEditor() {
		getEngine().executeScript("editor") as JSObject
	}
	
	def getEngine() {
		return webView.getEngine()
	}

}
