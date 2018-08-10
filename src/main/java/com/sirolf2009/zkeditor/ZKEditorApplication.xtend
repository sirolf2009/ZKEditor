package com.sirolf2009.zkeditor;

import java.io.IOException
import java.util.List
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import javafx.application.Application
import javafx.scene.Scene
import javafx.scene.control.TextInputDialog
import javafx.stage.Stage
import org.apache.zookeeper.Watcher.Event.KeeperState
import org.apache.zookeeper.ZooKeeper

class ZKEditorApplication extends Application {

	def static void main(String[] args) {
		launch(args)
	}

	override start(Stage primaryStage) throws Exception {
		val ip = if(getParameters().getRaw().size() == 1) {
			getParameters().getRaw().get(0)
		} else {
			promptForIP().orElseThrow[new RuntimeException("I need an IP to connect with")]
		}
		val zookeeper = connect(#[ip])

		val scene = new Scene(new ZKEditor(zookeeper), 1200, 600)
		primaryStage.setOnCloseRequest [
			zookeeper.close()
			System.exit(0)
		]
		primaryStage.setTitle(ip)
		primaryStage.setScene(scene)
		primaryStage.show()
	}

	def static promptForIP() {
		val dialog = new TextInputDialog("localhost:2181") => [
			setTitle("Connect")
			setHeaderText("Please enter an ip to connect with")
		]
		dialog.showAndWait()
	}

	def static connect(List<String> endPoints) {
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
