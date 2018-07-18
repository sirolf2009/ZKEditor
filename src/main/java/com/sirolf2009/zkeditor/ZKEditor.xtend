package com.sirolf2009.zkeditor;

import com.sirolf2009.treeviewhierarchy.TreeViewHierarchy
import java.io.IOException
import java.util.LinkedList
import java.util.List
import java.util.Optional
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import javafx.application.Application
import javafx.collections.FXCollections
import javafx.collections.ObservableList
import javafx.scene.Scene
import javafx.scene.control.Alert
import javafx.scene.control.Alert.AlertType
import javafx.scene.control.Button
import javafx.scene.control.ButtonBar
import javafx.scene.control.ButtonType
import javafx.scene.control.ContextMenu
import javafx.scene.control.MenuItem
import javafx.scene.control.SplitPane
import javafx.scene.control.TextArea
import javafx.scene.control.TextField
import javafx.scene.control.TextInputDialog
import javafx.scene.control.TreeItem
import javafx.scene.layout.Priority
import javafx.scene.layout.VBox
import javafx.stage.Stage
import org.apache.zookeeper.CreateMode
import org.apache.zookeeper.Watcher.Event.KeeperState
import org.apache.zookeeper.ZooDefs.Ids
import org.apache.zookeeper.ZooKeeper
import java.util.concurrent.atomic.AtomicReference

class ZKEditor extends Application {

	def static void main(String[] args) {
		launch(args)
	}

	override start(Stage primaryStage) throws Exception {
		val zookeeper = connect(#["localhost:2181"])

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

		val treeview = new TreeViewHierarchy(new TreeItem<ZKNode>()) => [
			val nodes = FXCollections.observableArrayList(zookeeper.buildTree())
			setItems(nodes)
			setShowRoot(false)

			val selectionModel = getSelectionModel()
			setContextMenu(new ContextMenu(new MenuItem("delete") => [
				setOnAction [
					val node = selectionModel.getSelectedItem()
					new Alert(AlertType.CONFIRMATION) => [
						setTitle("Confirm Deletion")
						setHeaderText('''Are you sure you want to delete «node.getValue().getPath()»?''')
						showAndWait().filter[it == ButtonType.OK].ifPresent [
							nodes.get(0).getParent(node.getValue()).get().getChildren().remove(node.getValue())
							zookeeper.delete(node.getValue().getPath(), -1)
						]
					]
				]
			], new MenuItem("add child") => [
				setOnAction [
					val parent = selectionModel.getSelectedItem()
					new TextInputDialog("child") => [
						setTitle("Enter Name")
						setHeaderText("Please enter a name for the child")
						showAndWait().ifPresent [
							val child = if(parent.getValue().getPath().equals("/")) {
									new ZKNode(it, "/" + it, FXCollections.observableArrayList())
								} else {
									new ZKNode(it, parent.getValue().getPath() + "/" + it, FXCollections.observableArrayList())
								}
							zookeeper.create(child.getPath(), #[], Ids.OPEN_ACL_UNSAFE, CreateMode.PERSISTENT)
							parent.getValue().getChildren().add(child)
						]
					]
				]
			]))
			selectionModel.selectedItemProperty().addListener [ obs, oldVal, newVal |
				path.setText(newVal.getValue().getPath())
				val data = zookeeper.getData(newVal.getValue().getPath(), false, null)
				if(data !== null) {
					textArea.setText(new String(data))
				} else {
					textArea.setText("")
				}
			]
		]
		val splitPane = new SplitPane(treeview, new VBox(path, textArea, tools))

		val scene = new Scene(splitPane, 1200, 600)
		primaryStage.setOnCloseRequest[
			zookeeper.close()
			System.exit(0)
		]
		primaryStage.setScene(scene)
		primaryStage.show()
	}

	def private static Optional<ZKNode> getParent(ZKNode root, ZKNode child) {
		val segments = new LinkedList(child.path.split("/"))
		segments.pop()
		val parent = new AtomicReference(null)
		val node = new AtomicReference(root)
		while(segments.size() > 0) {
			val now = node.get()
			node.get().getChildren().forEach[
				if(name.equals(segments.peek())) {
					parent.set(node.get())
					node.set(it)
					segments.pop()
				}
			]
			if(now === node.get()) {
				return Optional.empty()
			}
		}
		return Optional.ofNullable(parent.get())
	}

	def private static buildTree(ZooKeeper zookeeper) {
		new ZKNode("/", "/", FXCollections.observableArrayList(zookeeper.getChildren("/", false).map [
			new ZKNode(it, "/" + it, buildTree(zookeeper, "/" + it))
		]))
	}

	def private static ObservableList<ZKNode> buildTree(ZooKeeper zookeeper, String path) {
		FXCollections.observableArrayList(zookeeper.getChildren(path, false).map [
			new ZKNode(it, path + "/" + it, buildTree(zookeeper, path + "/" + it))
		])
	}

	def private static connect(List<String> endPoints) {
		val connectionLatch = new CountDownLatch(endPoints.size())
		val zookeeper = new ZooKeeper(endPoints.join(","), 2000, [
			if(getState().equals(KeeperState.SyncConnected)) {
				connectionLatch.countDown()
			}
		])
		if(!connectionLatch.await(1, TimeUnit.MINUTES)) {
			throw new IOException("Failed to connect")
		}
		return zookeeper
	}

}
