-- This file was automatically generated for the LuaDist project.

package = "dromozoa-xml"
version = "1.0-1"
-- LuaDist source
source = {
  tag = "1.0-1",
  url = "git://github.com/LuaDist-testing/dromozoa-xml.git"
}
-- Original source
-- source = {
--   url = "https://github.com/dromozoa/dromozoa-xml/archive/v1.0.tar.gz";
--   file = "dromozoa-xml-1.0.tar.gz";
-- }
description = {
  summary = "XML parser and toolkit";
  license = "GPL-3";
  homepage = "https://github.com/dromozoa/dromozoa-xml/";
  maintainer = "Tomoyuki Fujimori <moyu@dromozoa.com>";
}
dependencies = {
  "dromozoa-commons";
}
build = {
  type = "builtin";
  modules = {
    ["dromozoa.xml"] = "dromozoa/xml.lua";
    ["dromozoa.xml.element"] = "dromozoa/xml/element.lua";
    ["dromozoa.xml.escape"] = "dromozoa/xml/escape.lua";
    ["dromozoa.xml.node_list"] = "dromozoa/xml/node_list.lua";
    ["dromozoa.xml.parser"] = "dromozoa/xml/parser.lua";
    ["dromozoa.xml.selectors"] = "dromozoa/xml/selectors.lua";
    ["dromozoa.xml.write"] = "dromozoa/xml/write.lua";
  };
}