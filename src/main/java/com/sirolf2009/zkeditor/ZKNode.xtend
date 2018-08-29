package com.sirolf2009.zkeditor

import com.sirolf2009.treeviewhierarchy.IHierarchicalData
import javafx.collections.ObservableList
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

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
	
	override equals(Object obj) {
		if(obj instanceof ZKNode) {
			return obj.getPath().equals(path)
		}
		return false
	}
	
}