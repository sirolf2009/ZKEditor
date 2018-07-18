package com.sirolf2009.zkeditor

import com.sirolf2009.treeviewhierarchy.IHierarchicalData
import javafx.collections.ObservableList
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtend.lib.annotations.Accessors

@FinalFieldsConstructor @Accessors class ZKNode implements IHierarchicalData<ZKNode> {
	
	val String name
	val String path
	val ObservableList<ZKNode> children
	
	override toString() {
		return name
	}
	
	override getChildren() {
		return children
	}
	
}