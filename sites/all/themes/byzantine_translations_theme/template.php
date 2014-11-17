<?php

/**
 * @file
 * This file is empty by default because the base theme chain (Alpha & Omega) provides
 * all the basic functionality. However, in case you wish to customize the output that Drupal
 * generates through Alpha & Omega this file is a good place to do so.
 * 
 * Alpha comes with a neat solution for keeping this file as clean as possible while the code
 * for your subtheme grows. Please read the README.txt in the /preprocess and /process subfolders
 * for more information on this topic.
 */

/*
function byzantine_translations_theme_preprocess_search_results(&$variables) {
  if(!empty($variables['results'])) {
    $num_results = count($variables['results']);
  }
  $variables['num_results'] = $num_results;
}
*/
/*
function byzantine_translations_theme_preprocess_search_result(&$vars) {
  // custom functionality here
  //print "<pre>" . check_plain(print_r($vars), 1) . "</pre>";
  $n = node_load($vars['result']['node']->entity_id);
  $n && ($vars['node'] = $n);
  $vars['info'] = 0;
  
}
*/



/* review
http://api.drupalhelp.net/api/apachesolr/apachesolr_search.module/function/theme_apachesolr_search_snippets/7
*/


/*
function byzantine_translations_theme_apachesolr_search_snippets(&$vars) {
 $vars["byzantine_translations_theme_sample"] = "me"; 
 //return "me";
}
*/

function byzantine_translations_theme_preprocess_search_results(&$variables) {  
  $nids = array();
  
  foreach ($variables['results'] as $result) {
    if (!is_object($result['node'])) {
      continue;
    }
    if ($variables['module'] == 'apachesolr_search') {
      if ($result['node']->entity_type == 'node') {
        $nids[] = $result['node']->entity_id;
      }
    }
    else {
      $nids[] = $result['node']->nid;
    }
  }

  if (!count($nids)) {
    return;
  }
  
  // In my view I have one contextual filter which is content->nid and can have multiple values
  $view = views_embed_view('display', 'default', implode('+', $nids)); 

  // I want to see results count
  $variables['search_results_count'] = $variables['response']->response->numFound;
  //if ($view) $variables['search_results'] = $view; 
}

function byzantine_translations_theme_preprocess_page(&$variables) {
  if (!empty($variables['node']) && !empty($variables['node']->type)) {
    $variables['theme_hook_suggestions'][] = 'page__node__' . $variables['node']->type;
  }
}

