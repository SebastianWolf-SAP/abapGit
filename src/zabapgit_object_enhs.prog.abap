*&---------------------------------------------------------------------*
*&  Include           ZABAPGIT_OBJECT_ENHS
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
*       CLASS lcl_object_enhs DEFINITION
*----------------------------------------------------------------------*
CLASS lcl_object_enhs DEFINITION INHERITING FROM lcl_objects_super FINAL.

  PUBLIC SECTION.
    INTERFACES lif_object.
    ALIASES mo_files FOR lif_object~mo_files.

ENDCLASS. "lcl_object_enhs

*----------------------------------------------------------------------*
*       CLASS lcl_object_enhs IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS lcl_object_enhs IMPLEMENTATION.

  METHOD lif_object~has_changed_since.
    rv_changed = abap_true.
  ENDMETHOD.  "lif_object~has_changed_since

  METHOD lif_object~changed_by.

    DATA: lv_spot_name TYPE enhspotname,
          li_spot_ref  TYPE REF TO if_enh_spot_tool.


    lv_spot_name = ms_item-obj_name.

    TRY.
        li_spot_ref = cl_enh_factory=>get_enhancement_spot( lv_spot_name ).
        li_spot_ref->get_attributes( IMPORTING changedby = rv_user ).
      CATCH cx_enh_root.
        rv_user = c_user_unknown.
    ENDTRY.

  ENDMETHOD.

  METHOD lif_object~deserialize.

    DATA: lv_message          TYPE string,
          lv_parent           TYPE enhspotcompositename,
          lv_spot_name        TYPE enhspotname,
          lv_enh_shtext       TYPE string,
          ls_enh_badi         TYPE enh_badi_data,
          lt_enh_badi         TYPE enh_badi_data_it,
          lx_root             TYPE REF TO cx_root,
          lv_tool             TYPE enhspottooltype,
          lv_package          LIKE iv_package,
          li_spot_ref         TYPE REF TO if_enh_spot_tool,
          lo_badidef_tool     TYPE REF TO cl_enh_tool_badi_def,
          lo_hookdef_tool     TYPE REF TO cl_enh_tool_hook_def,
          lt_hook_definitions TYPE enh_hook_def_ext_it,
          li_enh_object       TYPE REF TO if_enh_object,
          li_enh_object_docu  TYPE REF TO if_enh_object_docu.

    lv_spot_name = ms_item-obj_name.

    io_xml->read( EXPORTING iv_name = 'TOOL'
                  CHANGING  cg_data = lv_tool ).
    io_xml->read( EXPORTING iv_name = 'SHORTTEXT'
                  CHANGING  cg_data = lv_enh_shtext ).

    IF lif_object~exists( ) = abap_true.
      lif_object~delete( ).
    ENDIF.

    lv_package = iv_package.

    TRY.
        cl_enh_factory=>create_enhancement_spot(
          EXPORTING
            spot_name      = lv_spot_name
            tooltype       = lv_tool
            dark           = abap_false
            compositename  = lv_parent
          IMPORTING
            spot           = li_spot_ref
          CHANGING
            devclass       = lv_package ).

        li_enh_object ?= li_spot_ref.
        li_enh_object_docu ?= li_spot_ref.

        li_enh_object_docu->set_shorttext( lv_enh_shtext ).

        CASE lv_tool.
          WHEN cl_enh_tool_badi_def=>tooltype.

            io_xml->read( EXPORTING iv_name = 'PARENT_COMP'
                          CHANGING  cg_data = lv_parent ).

            io_xml->read( EXPORTING iv_name = 'BADI_DATA'
                          CHANGING  cg_data = lt_enh_badi ).

            lo_badidef_tool ?= li_spot_ref.

            LOOP AT lt_enh_badi INTO ls_enh_badi.
              lo_badidef_tool->add_badi_def( ls_enh_badi ).
            ENDLOOP.

          WHEN cl_enh_tool_hook_def=>tool_type.

            io_xml->read( EXPORTING iv_name = 'BADI_DATA'
                          CHANGING  cg_data = lt_hook_definitions ).

            lo_hookdef_tool ?= li_spot_ref.

            LOOP AT lt_hook_definitions ASSIGNING FIELD-SYMBOL(<ls_hook_def>).
              lo_hookdef_tool->add_hook_def( CORRESPONDING #( <ls_hook_def> ) ).
            ENDLOOP.

        ENDCASE.

        li_enh_object->save( ).
        li_enh_object->activate( ).
        li_enh_object->unlock( ).

      CATCH cx_enh_root INTO lx_root.
        lv_message = `Error occured while deserializing EHNS: `
          && lx_root->get_text( ) ##NO_TEXT.
        zcx_abapgit_exception=>raise( lv_message ).
    ENDTRY.

  ENDMETHOD.  "deserialize

  METHOD lif_object~serialize.

    DATA: lv_spot_name        TYPE enhspotname,
          lv_enh_shtext       TYPE string,
          lv_parent           TYPE enhspotcompositename,
          lt_enh_badi         TYPE enh_badi_data_it,
          lv_tool             TYPE enhspottooltype,
          lx_root             TYPE REF TO cx_root,
          li_spot_ref         TYPE REF TO if_enh_spot_tool,
          lo_badidef_tool     TYPE REF TO cl_enh_tool_badi_def,
          lo_hookdef_tool     TYPE REF TO cl_enh_tool_hook_def,
          lt_hook_definitions TYPE enh_hook_def_ext_it,
          li_enh_object_docu  TYPE REF TO if_enh_object_docu.

    lv_spot_name = ms_item-obj_name.

    TRY.
        li_spot_ref = cl_enh_factory=>get_enhancement_spot( lv_spot_name ).
        lv_tool = li_spot_ref->get_tool( ).

        li_enh_object_docu ?= li_spot_ref.
        lv_enh_shtext = li_enh_object_docu->get_shorttext( ).

        io_xml->add( ig_data = lv_tool
                     iv_name = 'TOOL' ).
        io_xml->add( ig_data = lv_enh_shtext
                     iv_name = 'SHORTTEXT' ).

        CASE lv_tool.
          WHEN cl_enh_tool_badi_def=>tooltype.

            lo_badidef_tool ?= li_spot_ref.

            "get parent = composite enhs (ENHC)
            lv_parent = cl_r3standard_persistence=>enh_find_parent_composite( lv_spot_name ).
            "get subsequent BADI definitions
            lt_enh_badi = lo_badidef_tool->get_badi_defs( ).

            io_xml->add( ig_data = lv_parent
                         iv_name = 'PARENT_COMP' ).
            io_xml->add( ig_data = lt_enh_badi
                         iv_name = 'BADI_DATA' ).

          WHEN cl_enh_tool_hook_def=>tool_type.

            lo_hookdef_tool ?= li_spot_ref.

            lt_hook_definitions = lo_hookdef_tool->get_hook_defs( ).

            io_xml->add( ig_data = lt_hook_definitions
                         iv_name = 'BADI_DATA' ).

          WHEN OTHERS.
            zcx_abapgit_exception=>raise( |ENHS: Unsupported tool { lv_tool }| ).
        ENDCASE.

      CATCH cx_enh_root INTO lx_root.
        zcx_abapgit_exception=>raise( `Error occured while serializing EHNS: `
          && lx_root->get_text( ) ) ##NO_TEXT.
    ENDTRY.

  ENDMETHOD.  "serialize

  METHOD lif_object~exists.

    DATA: lv_spot_name TYPE enhspotname,
          lv_tool      TYPE enhspottooltype,
          li_spot_ref  TYPE REF TO if_enh_spot_tool.


    lv_spot_name = ms_item-obj_name.

    TRY.
        li_spot_ref = cl_enh_factory=>get_enhancement_spot( lv_spot_name ).

        lv_tool = li_spot_ref->get_tool( ).

        rv_bool = abap_true.

      CATCH cx_enh_root.
        rv_bool = abap_false.
    ENDTRY.

  ENDMETHOD.  "exists

  METHOD lif_object~delete.

    DATA: lv_spot_name  TYPE enhspotname,
          lx_root       TYPE REF TO cx_root,
          li_enh_object TYPE REF TO if_enh_object.

    lv_spot_name = ms_item-obj_name.

    TRY.
        li_enh_object ?= cl_enh_factory=>get_enhancement_spot(
                            spot_name = lv_spot_name
                            lock      = abap_true ).

        li_enh_object->delete( nevertheless_delete = abap_true
                               run_dark            = abap_true ).

        li_enh_object->unlock( ).

      CATCH cx_enh_root INTO lx_root.
        zcx_abapgit_exception=>raise( `Error occured while deleting EHNS: `
          && lx_root->get_text( ) ) ##NO_TEXT.
    ENDTRY.

  ENDMETHOD.  "delete

  METHOD lif_object~get_metadata.
    rs_metadata = get_metadata( ).
  ENDMETHOD.  "get_metadata

  METHOD lif_object~jump.

    CALL FUNCTION 'RS_TOOL_ACCESS'
      EXPORTING
        operation     = 'SHOW'
        object_name   = ms_item-obj_name
        object_type   = 'ENHS'
        in_new_window = abap_true.

  ENDMETHOD.  "jump

  METHOD lif_object~compare_to_remote_version.
    CREATE OBJECT ro_comparison_result TYPE lcl_comparison_null.
  ENDMETHOD.

ENDCLASS. "lcl_object_enhs
