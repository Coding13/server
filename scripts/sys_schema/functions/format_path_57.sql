-- Copyright (c) 2014, 2016, Oracle and/or its affiliates. All rights reserved.
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; version 2 of the License.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

DROP FUNCTION IF EXISTS format_path;

DELIMITER $$

CREATE DEFINER='root'@'localhost' FUNCTION format_path (
        in_path VARCHAR(512)
    )
    RETURNS VARCHAR(512) CHARSET UTF8
    COMMENT '
             Description
             -----------

             Takes a raw path value, and strips out the datadir or tmpdir
             replacing with @@datadir and @@tmpdir respectively. 

             Also normalizes the paths across operating systems, so backslashes
             on Windows are converted to forward slashes

             Parameters
             -----------

             path (VARCHAR(512)):
               The raw file path value to format.

             Returns
             -----------

             VARCHAR(512) CHARSET UTF8

             Example
             -----------

             mysql> select @@datadir;
             +-----------------------------------------------+
             | @@datadir                                     |
             +-----------------------------------------------+
             | /Users/mark/sandboxes/SmallTree/AMaster/data/ |
             +-----------------------------------------------+
             1 row in set (0.06 sec)

             mysql> select format_path(\'/Users/mark/sandboxes/SmallTree/AMaster/data/mysql/proc.MYD\') AS path;
             +--------------------------+
             | path                     |
             +--------------------------+
             | @@datadir/mysql/proc.MYD |
             +--------------------------+
             1 row in set (0.03 sec)
            '
    SQL SECURITY INVOKER
    DETERMINISTIC
    NO SQL
BEGIN
  DECLARE v_path VARCHAR(512);
  DECLARE v_dir VARCHAR(1024);
  DECLARE v_prefix VARCHAR(20);

  DECLARE path_separator CHAR(1) DEFAULT '/';

  IF @@global.version_compile_os LIKE 'win%' THEN
    SET path_separator = '\\';
  END IF;

  -- OSX hides /private/ in variables, but Performance Schema does not
  IF in_path LIKE '/private/%' THEN
    SET v_path = REPLACE(in_path, '/private', '');
  ELSE
    SET v_path = in_path;
  END IF;

  -- @@global.innodb_undo_directory is only set when separate undo logs are used
  IF v_path IS NULL THEN
    RETURN NULL;
  END IF;

  SET v_dir=@@global.datadir;
  SET v_prefix='@@datadir';
  IF v_path LIKE CONCAT(v_dir, IF(SUBSTRING(v_dir, -1) = path_separator, '%', CONCAT(path_separator, '%'))) ESCAPE '|' THEN
    SET v_path = REPLACE(v_path, v_dir, CONCAT(v_prefix, IF(SUBSTRING(v_path, -1) = path_separator, path_separator, '')));
  END IF;

  
  SET v_dir=@@global.datadir;
  SET v_prefix='@@datadir';
  IF v_path LIKE CONCAT(v_dir, IF(SUBSTRING(v_dir, -1) = path_separator, '%', CONCAT(path_separator, '%'))) ESCAPE '|' THEN
    SET v_path = REPLACE(v_path, v_dir, CONCAT(v_prefix, IF(SUBSTRING(v_path, -1) = path_separator, path_separator, '')));
  END IF;

  SET v_dir = IFNULL((SELECT VARIABLE_VALUE FROM information_schema.global_variables WHERE VARIABLE_NAME = 'innodb_data_home_dir'), '');
  SET v_prefix='@@innodb_data_home_dir';
  IF v_path LIKE CONCAT(v_dir, IF(SUBSTRING(v_dir, -1) = path_separator, '%', CONCAT(path_separator, '%'))) ESCAPE '|' THEN
    SET v_path = REPLACE(v_path, v_dir, CONCAT(v_prefix, IF(SUBSTRING(v_path, -1) = path_separator, path_separator, '')));
    RETURN v_path;
  END IF;

  SET v_prefix = '@@innodb_undo_directory';
  SET v_dir = IFNULL((SELECT VARIABLE_VALUE FROM information_schema.global_variables WHERE VARIABLE_NAME = 'innodb_undo_directory'), '');
  IF v_path LIKE CONCAT(v_dir, IF(SUBSTRING(v_dir, -1) = path_separator, '%', CONCAT(path_separator, '%'))) ESCAPE '|' THEN
    SET v_path = REPLACE(v_path, v_dir, CONCAT(v_prefix, IF(SUBSTRING(v_path, -1) = path_separator, path_separator, '')));
    RETURN v_path;
  END IF;

  SET v_dir = IFNULL((SELECT VARIABLE_VALUE FROM information_schema.global_variables WHERE VARIABLE_NAME = 'innodb_log_home_dir'), '');
  SET v_prefix = '@@innodb_log_home_dir';
  IF v_path LIKE CONCAT(v_dir, IF(SUBSTRING(v_dir, -1) = path_separator, '%', CONCAT(path_separator, '%'))) ESCAPE '|' THEN
    SET v_path = REPLACE(v_path, v_dir, CONCAT(v_prefix, IF(SUBSTRING(v_dir, -1) = path_separator, path_separator, '')));
    RETURN v_path;
  END IF;

  SET v_dir = IFNULL((SELECT VARIABLE_VALUE FROM information_schema.global_variables WHERE VARIABLE_NAME = 'slave_load_tmpdir'), '');
  SET v_prefix = '@@slave_load_tmpdir';
  IF v_path LIKE CONCAT(v_dir, IF(SUBSTRING(v_dir, -1) = path_separator, '%', CONCAT(path_separator, '%'))) ESCAPE '|' THEN
    SET v_path = REPLACE(v_path, v_dir, CONCAT(v_prefix, IF(SUBSTRING(v_dir, -1) = path_separator, path_separator, '')));
    RETURN v_path;
  END IF;

  SET v_dir = @@global.basedir;
  SET v_prefix = '@@basedir';
  IF v_path LIKE CONCAT(v_dir, IF(SUBSTRING(v_dir, -1) = path_separator, '%', CONCAT(path_separator, '%'))) ESCAPE '|' THEN
    SET v_path = REPLACE(v_path, v_dir, CONCAT(v_prefix, IF(SUBSTRING(v_dir, -1) = path_separator, path_separator, '')));
    RETURN v_path;
  END IF;

  RETURN v_path;
END$$

DELIMITER ;
