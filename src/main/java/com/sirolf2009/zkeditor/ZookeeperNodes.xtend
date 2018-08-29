package com.sirolf2009.zkeditor

import com.sirolf2009.treeviewhierarchy.TreeViewHierarchy
import com.sirolf2009.treeviewhierarchy.change.Addition
import io.reactivex.Maybe
import io.reactivex.Observable
import io.reactivex.schedulers.Schedulers
import java.util.LinkedList
import java.util.concurrent.atomic.AtomicReference
import javafx.application.Platform
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
import org.apache.zookeeper.KeeperException.NotEmptyException
import org.apache.zookeeper.ZKUtil
import org.apache.zookeeper.ZooDefs.Ids
import org.apache.zookeeper.ZooKeeper
import org.eclipse.xtend.lib.annotations.Accessors
import com.sirolf2009.treeviewhierarchy.change.Subtraction

@Accessors class ZookeeperNodes extends TreeViewHierarchy<ZKNode> {

	val StringProperty pathProperty = new SimpleStringProperty()
	val ObjectProperty<Maybe<byte[]>> valueProperty = new SimpleObjectProperty()
	val ObjectProperty<ZooKeeper> zookeeperProperty

	new(ZooKeeper zookeeper) {
		super(new TreeItem<ZKNode>())
		zookeeperProperty = new SimpleObjectProperty(zookeeper)
		updateItems()
		setShowRoot(false)

		focusedProperty().addListener [
			Observable.just(it).subscribeOn(Schedulers.io).map [
				zookeeperProperty.get().buildTree()
			].map [
				FXCollections.observableArrayList(zookeeperProperty.get().buildTree())
			].map [
				it.get(0).getDifferencesTo(getItems().get(0))
			].subscribe [
				Platform.runLater [
					forEach[
						if(it instanceof Addition) {
							getParent(getItems().get(0), (item as ZKNode).getPath()).subscribe [ parent |
								parent.getChildren().add((item as ZKNode))
							]
						} else if(it instanceof Subtraction) {
							getParent(getItems().get(0), (item as ZKNode).getPath()).subscribe [ parent |
								parent.getChildren().remove((item as ZKNode))
							]
						}
					]
				]
			]
		]

		val selectionModel = getSelectionModel()
		setContextMenu(new ContextMenu(new MenuItem("delete") => [
			setOnAction [
				val node = selectionModel.getSelectedItem()
				new Alert(AlertType.CONFIRMATION) => [
					setTitle("Confirm Deletion")
					setHeaderText('''Are you sure you want to delete «node.getValue().getPath()»?''')
					showAndWait().filter[it == ButtonType.OK].ifPresent [
						getItems().get(0).getParent(node.getValue()).subscribe [ parent |
							try {
								zookeeper.delete(node.getValue().getPath(), -1)
								parent.getChildren().remove(node.getValue())
							} catch(NotEmptyException e) {
								new Alert(AlertType.CONFIRMATION) => [
									setTitle("Confirm Deletion")
									setHeaderText('''«node.getValue().getPath()» is not empty. Would you like to delete recursively?''')
									showAndWait().filter[it == ButtonType.OK].ifPresent [
										ZKUtil.deleteRecursive(zookeeper, node.getValue().getPath())
										parent.getChildren().remove(node.getValue())
									]
								]
							}
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

	def updateItems() {
		setItems(FXCollections.observableArrayList(zookeeperProperty.get().buildTree()))
	}

	def private static buildTree(ZooKeeper zookeeper) {
		new ZKNode("/", "/", FXCollections.observableArrayList(zookeeper.getChildren("/", false).sort().map [
			new ZKNode(it, "/" + it, buildTree(zookeeper, "/" + it))
		]))
	}

	def private static ObservableList<ZKNode> buildTree(ZooKeeper zookeeper, String path) {
		FXCollections.observableArrayList(zookeeper.getChildren(path, false).sort().map [
			new ZKNode(it, path + "/" + it, buildTree(zookeeper, path + "/" + it))
		])
	}

	def private static Maybe<ZKNode> getParent(ZKNode root, ZKNode child) {
		return getParent(root, child.getPath())
	}

	def private static Maybe<ZKNode> getParent(ZKNode root, String path) {
		val segments = new LinkedList(path.split("/"))
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
				if(segments.size() == 1) {
					return Maybe.just(now)
				}
				return Maybe.empty()
			}
		}
		return Maybe.just(parent.get())
	}

}
