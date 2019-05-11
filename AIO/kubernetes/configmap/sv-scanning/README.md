======================
Notes on License Files
======================

This folder contains extra license and license-detection rule files that the
Acumos operator can configure for use with the SV Scanning Service. The following
notes are in development, and incomplete.

See `How to add a new license detection rule? <https://github.com/nexB/scancode-toolkit/wiki/FAQ>`_
on the `Scancode-toolkit github repo <https://github.com/nexB/scancode-toolkit>`_
for more info.

The following licenses and rules contained in this folder are for demonstration
and test purposes only:

*

+++++++++++++++
Licenses Folder
+++++++++++++++

This folder should contain two files for each license to be added. 'selected_base_name'
is a unique name that you can use to differentiate the licenses in this folder.
Ensure that the selected name does not conflict with one of the names in the
`scancode licenses folder <https://github.com/nexB/scancode-toolkit/tree/develop/src/licensedcode/data/licenses>`_ .

* 'selected_base_name'.yml

  * This contains attributes of the license that are needed for the reporting
    functions of the scancode-toolkit. The minimum fields are:

    * key: identifier to be used in the Acumos siteConfig verification key
    * name: full name of the license
    * short_name: short name of the license. This should be aligned with the
      license name as configured in the siteConfig verification key, as
      scancode will report the license name equivalent to this field, with spaces
      replaced by dashes.
    * category: one of

      * Commercial
      * Copyleft
      * Copyleft Limited
      * Free Restricted
      * Patent License
      * Permissive
      * Proprietary Free
      * Public Domain
      * Unstated License

* 'selected_base_name'.LICENSE

  * The typical text expression of the license

++++++++++++
Rules Folder
++++++++++++

This folder should contain two files for each variant of a rule to be used to
detect licenses. 'selected_base_name' is a unique name that you can use to
differentiate the licenses in this folder. 'variant' is a number from 1 to n.
Ensure that the selected name does not conflict with one of the names in the
`scancode rules folder <https://github.com/nexB/scancode-toolkit/tree/develop/src/licensedcode/data/rules>`_ .

* 'selected_base_name'_'variant'.RULE

  * typically, this should be a text snippet that can uniquely identify the
    license. Scancode supports a variety of rule features that can be used here,
    in addition to plain text.

* 'selected_base_name'_'variant'.yml

  * license_expression: value used as the 'key' in licenses/'selected_base_name'.yml
  * is_license_reference: 'yes', if this is a plain text rule
