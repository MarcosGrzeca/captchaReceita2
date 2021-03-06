#' Decodificar
#'
#' @param arq arquivo com o captcha
#' @param modelo modelo utilizado p/ prever
#' @param fun função usada p/ agregar os resultados.
#' 
#' @export
decodificar <- function(arq, modelo, fun = sum){
  arq %>%
    ler() %>%
    processar_nova_imagem() %>%
    predizer(modelo, fun)
}

#' Processar nova imagem
#'
#' @param img imagem
#' 
processar_nova_imagem <- function(img, cortes = list(
  "1" = c(25, 55, 85, 120, 147),
  "2" = c(30, 55, 87, 117, 145),
  "3" = c(27, 60, 87, 120, 148)
)){
  
  r <- plyr::ldply(cortes, function(c, img){
    processar(img, cortes = c) %>%
      preencher(20,20,0,1,1) %>%
      imagem_em_bd()
  }, img = img, .id = "corte")
  
  r$posicao <- as.factor(r$posicao)
  
  return(r)
}

#' Predizer
#'
#' @param bd banco de dados de uma imagem
#' @param modelo modelo utilizado p/ prever
#' @param fun função usada p/ agregar os resultados.
#'
predizer <- function(bd, modelo, fun = sum){
  
  pred <- predict(modelo, bd, type = "prob") %>% 
    data.frame() %>%
    dplyr::bind_cols(bd %>% dplyr::select(posicao)) %>%
    dplyr::filter(!is.na(X0)) %>%
    tidyr::gather(letra, valor, -posicao) %>%
    dplyr::group_by(posicao, letra) %>%
    dplyr::summarise(valor = fun(valor)) %>%
    dplyr::group_by(posicao) %>%
    dplyr::filter(valor == max(valor)) %>%
    dplyr::arrange(posicao)
  
  pred$letra <- stringr::str_replace_all(pred$letra, "X", "")
  
  paste(pred$letra, collapse = "")
}

#' Preparar banco de dados p/ modelo
#'
#' @param dir diretorio com todos os captchas já processados em data.frames
#'
#' @export
preparar <- function(dir, cortes = list(
  "1" = c(25, 55, 85, 120, 147),
  "2" = c(30, 55, 87, 117, 145),
  "3" = c(27, 60, 87, 120, 148)
)){
  r <- plyr::ldply(cortes, function(c, dir){
    arrumar(dir, cortes = c)
  }, dir = dir, .id = "corte")
  r$posicao <- as.factor(r$posicao)
  r$letras <- r$letras %>% tolower %>% as.factor
  return(r)
}

#' Separar em construção e validação
#'
#' @param bd banco de dados total.
#' @param n_validacao numero de casos na validação
#' @param seed semente usada 
#'
#' @export
separar <- function(bd, n_validacao = 100, seed = 500){
  set.seed(seed)
  
  bd_aux <- bd %>% 
    dplyr::select(arqs) %>% 
    unique() %>% 
    dplyr::sample_n(100)
  
  bd_teste <- dplyr::left_join(bd_aux, bd, by = "arqs")
  bd_treino <- dplyr::anti_join(bd, bd_teste, by = "arqs")
  
  return(list(
    "teste" = bd_teste,
    "treino" = bd_treino
  ))
}

#' Calcular erro
#'
#' @param bd bd p/ o qual vc quer calcular o erro
#'
#' @export
calcular_erro <- function(bd){
   predicoes <- bd %>% dplyr::group_by(arqs) %>% 
    dplyr::do(pred = predizer(., modelo))
   
   predicoes$real <- pegar_nome(predicoes$arqs) %>% tolower
   
   acerto_captcha <- mean(predicoes$real == predicoes$pred)
   
   predicoes_real <- predicoes$real %>% stringr::str_split("") %>% unlist
   predicoes_pred <- predicoes$pred %>% stringr::str_split("") %>% unlist
   acerto_letra <- mean(predicoes_real == predicoes_pred)
   
   data.frame(
     acerto = c("captcha", "letra"),
     valor = c(acerto_captcha, acerto_letra)
   )
}


