#!/usr/bin/env Rscript

# Workflow  Catastrophe Analysis

# inputs
#  * dataset
# output  
#   dataset :
#     misma cantidad de registros
#     misma cantidad de atributos
#     valores modificados para las  < variables, mes > que habian sido dañadas con un  0

# limpio la memoria
rm(list = ls(all.names = TRUE)) # remove all objects
gc(full= TRUE, verbose= FALSE) # garbage collection

require("data.table")
require("yaml")


# Instalación de "mice" (en caso de que sea necesario)
if(!("mice" %in% installed.packages()))
  install.packages("mice", repos = "http://cran.us.r-project.org")
library(mice)


#cargo la libreria
# args <- c( "~/labo2024ba" )
args <- commandArgs(trailingOnly=TRUE)
source( paste0( args[1] , "/src/lib/action_lib.r" ) )
#------------------------------------------------------------------------------

Corregir_MICE <- function(pcampo, pmeses) {

  meth <- rep("", ncol(dataset))
  names(meth) <- colnames(dataset)
  meth[names(meth) == pcampo] <- "sample"

  # llamada a mice  !
  imputacion <- mice(dataset,
    method = meth,
    maxit = 5,
    m = 1,
    seed = 7)

  tbl <- mice::complete(dataset)

  dataset[, paste0(pcampo) := ifelse(foto_mes %in% pmeses, tbl[, get(pcampo)], get(pcampo))]

}
#------------------------------------------------------------------------------

Corregir_interpolar <- function(pcampo, pmeses) {

  tbl <- dataset[, list(
    "v1" = shift(get(pcampo), 1, type = "lag"),
    "v2" = shift(get(pcampo), 1, type = "lead")
  ),
  by = eval(envg$PARAM$dataset_metadata$entity_id)
  ]

  tbl[, paste0(envg$PARAM$dataset_metadata$entity_id) := NULL]
  tbl[, promedio := rowMeans(tbl, na.rm = TRUE)]

  dataset[
    ,
    paste0(pcampo) := ifelse(!(foto_mes %in% pmeses),
      get(pcampo),
      tbl$promedio
    )
  ]
}
#------------------------------------------------------------------------------

AsignarNA_campomeses <- function(pcampo, pmeses) {

  if( pcampo %in% colnames( dataset ) ) {
  
    dataset[ foto_mes %in% pmeses, paste0(pcampo) := NA ]
  }
}
#------------------------------------------------------------------------------



Corregir_spline3 <- function(pcampo, pmeses) {
  cat ("Ejecutando spline3\n")
  cat("Calculando valores\n")
  tbl <- dataset[, .(
    #Obtengo valores validos
    validos = !foto_mes %in% pmeses,
    
    #Calculo spline3
    spline_fit = {
      if (length( !foto_mes %in% pmeses ) > 3) {  #Si tengo puntos para usar
        
        x_values <- seq_len(.N)  # Índices de las filas válidas
        y_values <- as.numeric(.SD[[pcampo]])
        
        #Spline para suavizado
        #spline_model <- smooth.spline(x_values, y_values, df = 3)
        #predict(spline_model, x_values)$y
        
        #Spline para interpolacion
        spl <- spline(x_values, y_values, xout = seq_len(.N), method = "fmm")  # Método 'fmm' = spline cúbico
        #Retorno valores interpolados
        as.numeric(spl$y)
        
      } else {
        as.numeric(get(pcampo))  # Retorna los valores originales si no hay suficientes datos
      }
    }
  ), by = numero_de_cliente ]
  
  cat("Reparando variable rota\n")
  #Corrijo valores erroneos
  dataset[,
          paste0(pcampo) := ifelse(foto_mes %in% pmeses,
                                   tbl$spline_fit,  # Replace with spline-predicted values in pmeses
                                   get(pcampo)  # Keep original values if not in pmeses
          )
  ]
}

#------------------------------------------------------------------------------

Corregir_atributo <- function(pcampo, pmeses, pmetodo) {
  cat( "inicio Corregir_Atributo()\n")
  # si el campo no existe en el dataset, Afuera !
  if( !(pcampo %in% colnames( dataset )) ){
    cat( paste("La variable",pcampo, "no se encuentra en el dataset()\n") )
    return( 1 )
  }

  # llamo a la funcion especializada que corresponde
  switch( pmetodo,
    "MachineLearning"     = AsignarNA_campomeses(pcampo, pmeses),
    "EstadisticaClasica"  = Corregir_interpolar(pcampo, pmeses),
    "MICE"                = Corregir_MICE(pcampo, pmeses),
    "spline3"             = Corregir_spline3(pcampo, pmeses)
  )

  return( 0 )
}
#------------------------------------------------------------------------------

Corregir_Rotas <- function(dataset, pmetodo) {
  gc()
  cat( "inicio Corregir_Rotas()\n")
  # acomodo los errores del dataset

  Corregir_atributo("active_quarter", c(202006), pmetodo) # 1
  Corregir_atributo("internet", c(202006), pmetodo) # 2

  Corregir_atributo("mrentabilidad", c(201905, 201910, 202006), pmetodo) # 3
  Corregir_atributo("mrentabilidad_annual", c(201905, 201910, 202006), pmetodo) # 4

  Corregir_atributo("mcomisiones", c(201905, 201910, 202006), pmetodo) # 5

  Corregir_atributo("mactivos_margen", c(201905, 201910, 202006), pmetodo) # 6
  Corregir_atributo("mpasivos_margen", c(201905, 201910, 202006), pmetodo) # 7

  Corregir_atributo("mcuentas_saldo", c(202006), pmetodo) # 8

  Corregir_atributo("ctarjeta_debito_transacciones", c(202006), pmetodo) # 9

  Corregir_atributo("mautoservicio", c(202006), pmetodo) # 10

  Corregir_atributo("ctarjeta_visa_transacciones", c(202006), pmetodo) # 11
  Corregir_atributo("mtarjeta_visa_consumo", c(202006), pmetodo) # 12

  Corregir_atributo("ctarjeta_master_transacciones", c(202006), pmetodo) # 13
  Corregir_atributo("mtarjeta_master_consumo", c(202006), pmetodo) # 14

  Corregir_atributo("ctarjeta_visa_debitos_automaticos", c(201904), pmetodo) # 15
  Corregir_atributo("mttarjeta_visa_debitos_automaticos", c(201904), pmetodo) # 16

  Corregir_atributo("ccajeros_propios_descuentos",
    c(201910, 202002, 202006, 202009, 202010, 202102), pmetodo) # 17

  Corregir_atributo("mcajeros_propios_descuentos",
    c(201910, 202002, 202006, 202009, 202010, 202102), pmetodo) # 18

  Corregir_atributo("ctarjeta_visa_descuentos",
    c(201910, 202002, 202006, 202009, 202010, 202102), pmetodo) # 19

  Corregir_atributo("mtarjeta_visa_descuentos",
    c(201910, 202002, 202006, 202009, 202010, 202102), pmetodo) # 20

  Corregir_atributo("ctarjeta_master_descuentos",
    c(201910, 202002, 202006, 202009, 202010, 202102), pmetodo) # 21

  Corregir_atributo("mtarjeta_master_descuentos",
    c(201910, 202002, 202006, 202009, 202010, 202102), pmetodo) # 22

  Corregir_atributo("ccomisiones_otras", c(201905, 201910, 202006), pmetodo) # 23
  Corregir_atributo("mcomisiones_otras", c(201905, 201910, 202006), pmetodo) # 24

  Corregir_atributo("cextraccion_autoservicio", c(202006), pmetodo) # 25
  Corregir_atributo("mextraccion_autoservicio", c(202006), pmetodo) # 26

  Corregir_atributo("ccheques_depositados", c(202006), pmetodo) # 27
  Corregir_atributo("mcheques_depositados", c(202006), pmetodo) # 28
  Corregir_atributo("ccheques_emitidos", c(202006), pmetodo) # 29
  Corregir_atributo("mcheques_emitidos", c(202006), pmetodo) # 30
  Corregir_atributo("ccheques_depositados_rechazados", c(202006), pmetodo) # 31
  Corregir_atributo("mcheques_depositados_rechazados", c(202006), pmetodo) # 32
  Corregir_atributo("ccheques_emitidos_rechazados", c(202006), pmetodo) # 33
  Corregir_atributo("mcheques_emitidos_rechazados", c(202006), pmetodo) # 34

  Corregir_atributo("tcallcenter", c(202006), pmetodo) # 35
  Corregir_atributo("ccallcenter_transacciones", c(202006), pmetodo) # 36

  Corregir_atributo("thomebanking", c(202006), pmetodo) # 37
  Corregir_atributo("chomebanking_transacciones", c(201910, 202006), pmetodo) # 38

  Corregir_atributo("ccajas_transacciones", c(202006), pmetodo) # 39
  Corregir_atributo("ccajas_consultas", c(202006), pmetodo) # 40

  Corregir_atributo("ccajas_depositos", c(202006, 202105), pmetodo) # 41

  Corregir_atributo("ccajas_extracciones", c(202006), pmetodo) # 41
  Corregir_atributo("ccajas_otras", c(202006), pmetodo) # 43

  Corregir_atributo("catm_trx", c(202006), pmetodo) # 44
  Corregir_atributo("matm", c(202006), pmetodo) # 45
  Corregir_atributo("catm_trx_other", c(202006), pmetodo) # 46
  Corregir_atributo("matm_other", c(202006), pmetodo) # 47

  cat( "fin Corregir_rotas()\n")
}
#------------------------------------------------------------------------------
# elimino atributos del dataset

eliminar_atributo <- function( patributo ) {

  if( patributo %in% colnames( dataset ) ) {
    dataset[, paste0( patributo, "") := NULL ]
  }
}
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# Aqui empieza el programa
cat( "z1201_CA_reparar_dataset.r  START\n")
action_inicializar() 

# cargo el dataset
envg$PARAM$dataset <- paste0( "./", envg$PARAM$input, "/dataset.csv.gz" )
envg$PARAM$dataset_metadata <- read_yaml( paste0( "./", envg$PARAM$input, "/dataset_metadata.yml" ) )

cat( "lectura del dataset\n")
action_verificar_archivo( envg$PARAM$dataset )
cat( "Iniciando lectura del dataset\n" )
dataset <- fread(envg$PARAM$dataset)
cat( "Finalizada lectura del dataset\n" )


# elimino varaibles 

for( atributo in  envg$PARAM$atributos_eliminar ){
  eliminar_atributo(  atributo )
}

GrabarOutput()

# ordeno dataset
setorderv(dataset, envg$PARAM$dataset_metadata$primarykey)

# aqui se hace el trabajo pesado
# si NO son "Ninguno"  aplico el metodo
if( envg$PARAM$metodo %in% c("MachineLearning", "EstadisticaClasica", "MICE", "spline3") )
  Corregir_Rotas(dataset, envg$PARAM$metodo)

#------------------------------------------------------------------------------
# grabo el dataset
cat( "grabado del dataset\n")
cat( "Iniciando grabado del dataset\n" )
fwrite(dataset,
  file = "dataset.csv.gz",
  logical01 = TRUE,
  sep = ","
)
cat( "Finalizado grabado del dataset\n" )

# copia la metadata sin modificar
cat( "grabado metadata\n")
write_yaml( envg$PARAM$dataset_metadata, 
  file="dataset_metadata.yml" )

#------------------------------------------------------------------------------

# guardo los campos que tiene el dataset
tb_campos <- as.data.table(list(
  "pos" = 1:ncol(dataset),
  "campo" = names(sapply(dataset, class)),
  "tipo" = sapply(dataset, class),
  "nulos" = sapply(dataset, function(x) {
    sum(is.na(x))
  }),
  "ceros" = sapply(dataset, function(x) {
    sum(x == 0, na.rm = TRUE)
  })
))

fwrite(tb_campos,
  file = "dataset.campos.txt",
  sep = "\t"
)

#------------------------------------------------------------------------------
cat( "Fin del programa\n")

envg$OUTPUT$dataset$ncol <- ncol(dataset)
envg$OUTPUT$dataset$nrow <- nrow(dataset)
envg$OUTPUT$time$end <- format(Sys.time(), "%Y%m%d %H%M%S")
GrabarOutput()

#------------------------------------------------------------------------------
# finalizo la corrida
#  archivos tiene a los files que debo verificar existen para no abortar

action_finalizar( archivos = c("dataset.csv.gz","dataset_metadata.yml")) 
cat( "z1201_CA_reparar_dataset.r  END\n")
