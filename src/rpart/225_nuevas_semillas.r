# como generar muchas semillas a partir de una

require("primes")

# genero numeros primos
primos <- generate_primes(min = 100000, max = 1000000)


set.seed(101023) # inicializo 

# me quedo con por ejemplo 20 primos al azar
semillas <- sample(primos, 10 )

print( semillas )

#nros primos
#c(101023, 214309,421013, 651127, 985057)