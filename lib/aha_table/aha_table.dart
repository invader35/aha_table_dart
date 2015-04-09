import 'package:polymer/polymer.dart';
import 'dart:convert';
import 'package:template_binding/template_binding.dart';
import 'dart:html';
import 'package:aha_table/aha_column/aha_column.dart';
import 'package:polymer_expressions/filter.dart';

class StringToInt extends Transformer<String, int> {
  String forward(int i) => i.toString();
  int reverse(String s) {
    try {
      return int.parse(s);
    } catch (e) {
      return null;
    }
  }
}

@CustomTag('aha-table')
class AhaTable extends PolymerElement {
  
  AhaTable.created() : super.created();

    //data: instance of the model data
    @published List data = [];
    //meta: instance of the model meta
    @published List meta = [];
    /**
     * modified: all created or modified row will be referenced here.
     * it's hard to determine if it's created or modified after multiple
     * operations, because the element doesn't assume there's an id column,
     * so you need to determine if by yourself, like check
     * if the id exists if your model has an id column.
     */
    @published List modified = [];
    //deleted: all deleted row will be moved here.
    @published List deleted = [];
    //selected: all selected row will be referenced here.
    @published ObservableList selectedRows = toObservable([]);
    //selectable: if table row is selectable
    @published bool selectable = false;
    //copyable: if table row is copyable
    @published bool copyable = false;
    //removable: if table row is removable
    @published bool removable = false;
    //searchable: if table row is searchable
    @published bool searchable = false;
    // text displayed in first column of search row.
    @published String searchtitle = "";
    // text displayed as title of select checkbox.
    @published String selecttitle = "";
    // text displayed as title of selectall checkbox.
    @published String selectalltitle = "";
    // text displayed as title of sorting column.
    @published String sorttitle = "";
    // text displayed as title of column name.
    @published String columntitle = "";
    // text displayed as title of copy indicator.
    @published String copytitle = "";
    // text displayed as title of remove checkbox..
    @published String removetitle = "";
    // text displayed as title of editable cell.
    @published String edittitle = "";
    //sortedColumn: sorted column name
    @published String sortedColumn;
    //editingRow: current editing row
    //@type {Object}
    @published Map editingRow = null;
    //if filtering has been performed.
    @published bool filtered = false;
    //editingRow: current rows in display/view
    @published Iterable viewingRows = [];
    //descending: current sorting order
    @published bool descending = false;
    //pagesize: the number of items to show per page
    @published int pagesize = 10;
    //currentpage: the current active page in view
    @published int currentpage = 0;
    //pageCount: the number of paginated pages
    @published int pageCount = 0;
    //itemCount: the number of visible items
    @published int itemCount = 0;
    //firstItemIndex: the index number of first item in the page, start from 1
    @published int firstItemIndex = 1;
    //lastItemIndex: the index number of last item in the page, start from 1
    @published int lastItemIndex = 1;
    //sizelist: range list to adjust page size.
    @published List sizelist = [5, 10, 20, 50, 100];
    //previous: label for the Previous button
    @published String previous = "<";
    //next: label for the Next button
    @published String next = ">";
    //first: label for the First page button
    @published String first = "<<";
    //last: label for the Last page button
    @published String last = ">>";
    //pagesizetitle: label for page size box
    @published String pagesizetitle = "";
    //summarytitle: label for table summary area
    @published String summarytitle = "";
    @published String firsttitle, 
            nexttitle,
            previoustitle, 
            lasttitle,
            pagetext, 
            pageoftext, 
            pagesizetext, 
            summarytext, 
            itemoftext;
    
    final asInt = new StringToInt();

    ready() {
      //Show element when it's ready.
      $['aha_table_main'].attributes.remove('unresolved');

      currentpage = 1;
    }

     //=========
    //internal methods
    dataChanged() {
//      if (meta.length == 0)  {
//        $['aha_table_main'].setAttribute('unresolved', '');
//        // generate meta from data if meta is not provided from aha-column.
//        meta = [];
//        for (var prop in data[0]) {
//          if (prop.indexOf('_') != 0) {//skip internal field
//            meta.add({
//              'name': prop,
//              'label': prop.charAt(0).toUpperCase() + prop.slice(1), 
//              'type': [true, false].indexOf(data[0][prop]) > -1 ? "boolean" : "string", 
//              'sortable': true, 
//              'searchable': true, 
//              'editable': true, 
//              'required': false
//            });
//          }
//        }
//        $['aha_table_main'].setAttribute('resolved', '');
//        $['aha_table_main'].removeAttribute('unresolved');
//      }
      refreshPagination(true);
    }

    modifiedChanged() {}

    //translate value to labels for select
    translate2(value, options, blank){
      if (value != "" && options) {
        for (var i = options.length - 1; i >= 0; i--) {
          if (options[i].value == value) {
            return options[i].label;
          }
        };
      }
      value = value == null ? '' : value;
      return value == "" ? blank : value;
    }

    capitalize(value) {
//      if (value is! String || value.length == 0) 
//        return value;
//      return value.charAt(0).toUpperCase() + value.slice(1);
      return value;
    }

    edited(e) {
      var row = nodeBind(e.target).templateInstance.model['row'];
      row['_editing'] = true;
      if (editingRow != null && editingRow != row) {
        editingRow['_editing'] = false;
      }
      editingRow = row;
    }

    save(e) {
      ObservableMap row    = nodeBind(e.target).templateInstance.model['row'];
      var column = nodeBind(e.target).templateInstance.model['column'];
      if(row != null){
        if ("CHECKBOX" == e.target.type.toUpperCase()) {
          row[column.name] = e.target.checked;
        } else {
          row[column.name] = e.target.value;
        }
        if (modified.indexOf(row) == -1) {
          row['_modified'] = true;
          modified.add(row);
        }

        //TODO: check correctly
//        if (!e.relatedTarget 
//          || !e.relatedTarget.templateInstance
//          || e.relatedTarget.templateInstance.model.row != nodeBind(e.target).templateInstance.model['row']) {
          row['_editing'] = false;
//        }

        if (column.required != null && !e.target.validity.valid) {
          fire('after-invalid', detail: {"event": e, "row" : row, "column" : column});
        }
      }
    }

    handleSort(Event e) {
      AhaColumn column = nodeBind(e.target).templateInstance.model['column'];
      if(column != null && column.sortable){
        var sortingColumn = column.name;
        if (sortingColumn == sortedColumn){
          descending = !descending;
        } else {
          sortedColumn = sortingColumn;
        }
      }

      refreshPagination();
    }
    
    @observable ObservableMap<String, dynamic> searchMap = toObservable({});
    
    List _filteredRows;

    search(event, details, target) {
      AhaColumn column = nodeBind(target).templateInstance.model['column'];
      
      searchMap[column.name] = "CHECKBOX" == target.type.toUpperCase() ? target.checked : target.value;
      
      refreshPagination();
    }

    //============
    //pagination
    firstPage() {
      currentpage = 1;
    }

    prevPage() {
      if(currentpage == null) {
        currentpage = 1;
      }
      if ( currentpage > 1 ) {
        currentpage--;
      }
    }

    nextPage() {
      if(currentpage == null) {
        currentpage = pageCount;
      }
      if ( currentpage < pageCount ) {
        currentpage++;
      }
    }

    lastPage() {
      currentpage = pageCount;
    }

    currentpageChanged(){
      if(currentpage != null) {
        currentpage = currentpage < 1 ? 1 : currentpage;
        currentpage = pageCount > 0 && currentpage > pageCount ? pageCount : currentpage;
        filterPage();
        firstItemIndex = (currentpage-1) * pagesize+1;
      }
    }

    pagesizeChanged(){
//      pagesize = parseInt(pagesize);
      refreshPagination();
    }

    // call this when total count is no changed.
    filterPage() {
      var from = (currentpage-1) * pagesize;
      var to   = from + pagesize;

      _filteredRows = data.where((row) {
        bool result = true;
        searchMap.forEach((searchedCol, searchVal) {
          if(row[searchedCol] is bool)
            result = result && row[searchedCol] == searchVal;
          else
            result = result && row[searchedCol].toString().toLowerCase()
              .contains(searchVal.toString().toLowerCase());
        });
        return result;
      }).toList();
      
      itemCount = _filteredRows.length;

      if (currentpage == pageCount) {
        lastItemIndex = itemCount;
      } else {
        lastItemIndex = (currentpage)* pagesize;
      }
      

      if (sortedColumn != null) {
        _filteredRows.sort((rowA, rowB) =>
            descending 
              ? rowA[sortedColumn].compareTo(rowB[sortedColumn])
              : rowB[sortedColumn].compareTo(rowA[sortedColumn]));
      }
      
        if(_filteredRows.length > to)
          viewingRows = _filteredRows.getRange(from, to);
        else
          viewingRows = _filteredRows.getRange(from, _filteredRows.length);

      selectedRowsChanged();
    }

    // call when total count is change.
    refreshPagination([keepInTheCurentPage = false]) {
      if (!keepInTheCurentPage) {
        // Usually go to the first page is the best way to avoid chaos.
        currentpage = 1;
      }
      
      itemCount = _filteredRows.length;
      pageCount = ( itemCount / pagesize ).ceil();

      // Update model bound to UI with filtered range
      filterPage();
    }

    //data manipulation//
    handleTdClick(e) {
      var column = nodeBind(e.target).templateInstance.model['column'];
      var row = nodeBind(e.target).templateInstance.model['row'];
      var detail = {"row" : row, "column" : column};
      if (column.editable) {
        edited(e);
      }
      fire('after-td-click', detail: detail);
    }

    handleTdDblClick(e,p) {
      var column = nodeBind(e.target).templateInstance.model['column'];
      var row = nodeBind(e.target).templateInstance.model['row'];
      var detail = {"row" : row, "column" : column};
      fire('after-td-dbclick', detail: detail);
    }

    select(e,p){
      if (selectable) {
        var row = nodeBind(e.target).templateInstance.model['row'];
        if(selectedRows.contains(row)) {
          // TODO: Check why remove doesn't work
//          selectedRows.remove(row);
          selectedRows = toObservable([]..addAll(selectedRows..remove(row)));
        } else {
          // TODO: Check why add doesn't work
          selectedRows = toObservable([]..addAll(selectedRows..add(row)));
//          selectedRows.add(row);
        }
      }
    }
    
    selectall(e,p){
      if(e.target.checked){
        selectedRows = toObservable(viewingRows);
      }else{
        selectedRows = toObservable([]);
      }
    }
    
//    @ObserveProperty('selectedRows')
//    bool get allSelected => 
//        viewingRows.fold(true, (all, row) {
//    return all && selectedRows.contains(row);
//  });
    
    @observable bool allSelected;
    
    selectedRowsChanged() {
      allSelected = viewingRows.fold(true, (all, row) {
        return all && selectedRows.contains(row);
      });
    }

    create(obj) {
      fire('before-create', detail: obj);
      var _default = {'_editing': true, '_modified': true};
      var _new = obj != null ? obj : _default;
      meta.forEach((column) {
        if (column.defaultVal && _new[column.name] == null) {
          _new[column.name] = column.defaultVal;
        }
      });
      data.insert(0,_new);
      modified.add(_new);
      fire('after-create', detail: _new);
    }

    copy(e, detail, sender) {
      var obj = nodeBind(e.target).templateInstance.model['row'];
      fire('before-copy', detail: obj);
      var _new = JSON.decode(JSON.encode(obj));
      if (_new.id) {
        _new.id = null;
      }
      if (_new._selected) {
        _new._selected = false;
      }
      _new._modified = true;
      _new._editing = false;
      data.insert(0,_new);
      modified.add(_new);
      fire('after-copy', detail: _new);
    }

    removed(e, detail, sender) {
      var obj = nodeBind(e.target).templateInstance.model['row'];
      fire('before-remove', detail:  obj);
      var found_index = data.indexOf(obj);
      if (found_index != -1) {
        data.removeAt(found_index);
        deleted.add(obj);
      }
      var found_index_in_modified = modified.indexOf(obj);
      if (found_index_in_modified != -1) {
        obj._modified = false;
        modified.removeAt(found_index_in_modified);
      }
      fire('after-remove', detail: obj);
    }

    toggleFilters() {
      searchable = !searchable;
      searchMap.clear();
      filterPage();
    }

}