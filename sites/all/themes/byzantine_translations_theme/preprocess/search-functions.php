<?php

function byzantine_translations_theme_alpha_preprocess_search_result(&$vars) {
  // custom functionality here
  $n = node_load($var['result']['node']->nid);
  $n && ($vars['node'] = $n);  
}

