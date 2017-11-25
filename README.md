minetest-teaching
=================

Teaching mod for Minetest

Nodes
-----

* 'Utility blocks': A-Z 0-9 (+Polish letters) and operators; util nodes light up on punch (teacher only)
* Lab block: Decoration block
* Lab Checking block: Checks solutions and can give a reward
* Lab Allow-dig block: Allows students to dig the block above it
* Infobox block: Glowing decoration block

Chat commands
-------------

* `alphabetize <string>`: Gives to player all characters in the string as util nodes

Privileges
----------

* teacher: Allows modifying Checking blocks and building
* freebuild: Allows building freely (without one of teacher & freebuild only utility blocks can be dug/placed on top of checking blocks)

Supporting resources
--------------------

* `generate`: a Bash script to generate hires textures for all the nodes using a chosen font (requires imagemagick)
