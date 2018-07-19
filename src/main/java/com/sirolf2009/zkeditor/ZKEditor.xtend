package com.sirolf2009.zkeditor

import javafx.geometry.Orientation
import javafx.scene.control.Button
import javafx.scene.control.ButtonBar
import javafx.scene.control.SplitPane
import javafx.scene.control.TextArea
import javafx.scene.control.TextField
import javafx.scene.layout.Priority
import javafx.scene.layout.VBox
import org.apache.zookeeper.ZooKeeper

class ZKEditor extends SplitPane {
	
	new(ZooKeeper zookeeper) {
		orientation = Orientation.HORIZONTAL
		val path = new TextField()
		path.setEditable(false)
		val textArea = new TextArea()
		VBox.setVgrow(textArea, Priority.ALWAYS)
		val tools = new ButtonBar() => [
			buttons.add(new Button("save") => [
				setOnAction [
					zookeeper.setData(path.getText(), textArea.getText().getBytes(), -1)
				]
			])
			buttons.add(new Button("reload") => [
				setOnAction [
					textArea.setText(new String(zookeeper.getData(path.getText(), false, null)))
				]
			])
		]

		val treeview = new ZookeeperNodes(zookeeper) => [
			pathProperty.addListener[obs,oldVal,newVal|
				path.setText(newVal)				
			]
			valueProperty.addListener[obs,oldVal,newVal|
				textArea.setText("")
				newVal.subscribe [
					textArea.setText(new String(it))
				]
			]
		]
		getItems().add(treeview)
		getItems().add(new VBox(path, textArea, tools))
	}
	
}