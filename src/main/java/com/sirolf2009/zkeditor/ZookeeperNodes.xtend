package com.sirolf2009.zkeditor

import com.sirolf2009.treeviewhierarchy.TreeViewHierarchy
import io.reactivex.Maybe
import java.util.LinkedList
import java.util.concurrent.atomic.AtomicReference
import javafx.beans.property.ObjectProperty
import javafx.beans.property.SimpleObjectProperty
import javafx.beans.property.SimpleStringProperty
import javafx.beans.property.StringProperty
import javafx.collections.FXCollections
import javafx.collections.ObservableList
import javafx.scene.control.Alert
import javafx.scene.control.Alert.AlertType
import javafx.scene.control.ButtonType
import javafx.scene.control.ContextMenu
import javafx.scene.control.MenuItem
import javafx.scene.control.TextInputDialog
import javafx.scene.control.TreeItem
import org.apache.zookeeper.CreateMode
import org.apache.zookeeper.ZooDefs.Ids
import org.apache.zookeeper.ZooKeeper
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors class ZookeeperNodes extends TreeViewHierarchy<ZKNode> {
	
	val StringProperty pathProperty = new SimpleStringProperty()
	val ObjectProperty<Maybe<byte[]>> valueProperty = new SimpleObjectProperty()

	new(ZooKeeper zookeeper) {
		super(new TreeItem<ZKNode>())
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
						nodes.get(0).getParent(node.getValue()).subscribe [
							getChildren().remove(node.getValue())
							zookeeper.delete(node.getValue().getPath(), -1)
						]
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
			pathProperty.set(newVal.getValue().getPath())
			val data = zookeeper.getData(newVal.getValue().getPath(), false, null)
			if(data !== null) {
				valueProperty.set(Maybe.just(data))
			} else {
				valueProperty.set(Maybe.empty())
			}
		]
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

	def private static Maybe<ZKNode> getParent(ZKNode root, ZKNode child) {
		val segments = new LinkedList(child.path.split("/"))
		segments.pop()
		val parent = new AtomicReference(null)
		val node = new AtomicReference(root)
		while(segments.size() > 0) {
			val now = node.get()
			node.get().getChildren().forEach [
				if(name.equals(segments.peek())) {
					parent.set(node.get())
					node.set(it)
					segments.pop()
				}
			]
			if(now === node.get()) {
				return Maybe.empty()
			}
		}
		return Maybe.just(parent.get())
	}

}
