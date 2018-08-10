package com.sirolf2009.zkeditor

import com.sirolf2009.zkeditor.editor.json.JSonEditor
import com.sirolf2009.zkeditor.editor.text.TextEditor
import javafx.beans.property.SimpleObjectProperty
import javafx.beans.property.SimpleStringProperty
import javafx.geometry.Orientation
import javafx.scene.Node
import javafx.scene.control.Button
import javafx.scene.control.ButtonBar
import javafx.scene.control.ComboBox
import javafx.scene.control.SplitPane
import javafx.scene.control.TextField
import javafx.scene.layout.AnchorPane
import javafx.scene.layout.Priority
import javafx.scene.layout.VBox
import org.apache.zookeeper.ZooKeeper
import org.eclipse.xtend.lib.annotations.Data

class ZKEditor extends SplitPane {
	
	val editor = new SimpleObjectProperty<IEditor>()
	val text = new SimpleStringProperty()
	
	new(ZooKeeper zookeeper) {
		orientation = Orientation.HORIZONTAL
		val path = new TextField()
		path.setEditable(false)
		
		val editorAnchor = new AnchorPane()
		VBox.setVgrow(editorAnchor, Priority.ALWAYS)
		editor.addListener[obs,oldVal,newVal|
			editorAnchor.getChildren().clear()
			editorAnchor.getChildren().add(newVal as Node)
			(newVal as Node).maximize()
			newVal.setText(text.get())
		]
		text.addListener[obs,oldVal,newVal|
			try {
				editor.get().setText(newVal)
			} catch(Exception e) {
				
			}
		]
		
		val tools = new ButtonBar() => [
			buttons.add(new ComboBox() => [
				getItems().add(new EditorSupplier("Text Editor", new TextEditor()))
				getItems().add(new EditorSupplier("Json Editor", new JSonEditor()))
				getSelectionModel().selectedItemProperty().addListener[obs,oldVal,newVal|
					editor.set(newVal.getEditor())
				]
				getSelectionModel().select(0)
			])
			buttons.add(new Button("save") => [
				setOnAction [
					zookeeper.setData(path.getText(), editor.get().getText().getBytes(), -1)
				]
			])
			buttons.add(new Button("reload") => [
				setOnAction [
					editor.get().setText(new String(zookeeper.getData(path.getText(), false, null)))
				]
			])
		]

		val treeview = new ZookeeperNodes(zookeeper) => [
			pathProperty.addListener[obs,oldVal,newVal|
				path.setText(newVal)				
			]
			valueProperty.addListener[obs,oldVal,newVal|
				text.set("")
				newVal.subscribe [
					text.set(new String(it))
				]
			]
		]
		getItems().add(treeview)
		getItems().add(new VBox(path, editorAnchor, tools))
	}
	
	def static maximize(Node node) {
		AnchorPane.setTopAnchor(node, 0d)
		AnchorPane.setRightAnchor(node, 0d)
		AnchorPane.setBottomAnchor(node, 0d)
		AnchorPane.setLeftAnchor(node, 0d)
	}
	
	@Data private static class EditorSupplier {
		String name
		IEditor editor
		
		override toString() {
			return name
		}
	}
	
}