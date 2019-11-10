
/**
 * Name: Simullation athmospherique dans un milieu urbain
 * Author: Steven Cib.
 * Description: Systeme Multi-agents, Pollutiion de l'air, Pollution athmospherique, Trafic routier 
 */
 
model pollution_athmospherique

global {
    file shape_file_buildings <- file("../includes/building.shp");
    file shape_file_roads <- file("../includes/road.shp");
    file shape_file_capteur <- file("../includes/capteur.shp");
    
    date system_start_time <- date("2019-10-30 06:00:00");
       
    /*observation de l'evolution des agetns */
    
    int nbrmoto -> {length(deuxRoues)};
    int nbrvp -> {length(vehiculeParticulier)};
    int nbrvult -> {length(vehiculeUtilitaire)};
    int nbrpl -> {length(poidsLourd)};
    int nbrtree -> {length(tree)};
   
    
    int nbr_moto <- 100;
    int nbr_vp <- 50;
    int nbr_vul <- 50;
    int nbr_pl <- 50;
    int nbr_tree <- 25;
     
     /*la vitesse du vehicule suivant son type*/
     
    float min_speed_moto <- 10.0 #km / #h;
    float max_speed_moto <- 60.0 #km / #h;
    
    float min_speed_vp <- 20.0 #km / #h;
    float max_speed_vp <- 80.0 #km / #h;  
    
    float min_speed_vul <- 30.0 #km / #h;
    float max_speed_vul <- 120.0 #km / #h;  
    
    float min_speed_pl <- 80.0 #km / #h;
    float max_speed_pl <- 180.0 #km / #h;  
    
    graph graph_road;
    
    /*estimation du debut et de la fin des activites journalieres*/
    
    int max_start <- 9;
    int min_start <- 6;
    int max_stop <- 23;
    int min_stop <- 16;
    
    geometry shape <- envelope(shape_file_roads);
    
    init {
	    create road from: shape_file_roads ;
	    graph_road <- as_edge_graph(road);  
	    
	    /*on a trois type de categorie de buildings soit un batiment sert de parking, soit il sert d'habitation soit de place de travail */
	    
	    create building from: shape_file_buildings with: [category::string(read ("service"))] 
	    {
	    	if category="parking" {color <- #olive;}
	    	
	    	if category="habitation" {color <- #wheat;}
	    	
	    	if category="working" {color <- #teal;}
	    }
	    
	    /*creation des agents vehicule qui jouent le role d'emettre le gaz dans l'athmosphere */
	        
	    create deuxRoues number: nbr_moto {}
	    create vehiculeParticulier number: nbr_pl{}
	    create vehiculeUtilitaire number: nbr_vul{}
	    create poidsLourd number: nbr_vp{}
	    
	    /*creation des agents arbre, vent et pluie eux qui influent positivement sur la pollution*/
	    
	    create tree number: nbr_tree{}
	    create vent{}
	    create pluie{}
	    
	    /*capteur sert d'estimation de la quantite du gaz emis par chaque vehicule et centre pour l'effichage*/
	    
	    create capteur from: shape_file_capteur;
	    create centre number: 1 {}
    }
    
    /*du fait que la majorite des agents du systeme ne se multiplient part eux meme, ainsi chaque apres 60 cycles les systeme en genere */
    
    reflex create_agents when: every(60#cycles)
    {
    	create tree number: 5{}
    	create deuxRoues number: 3{}
    	create vehiculeParticulier number: 3{}
    	create vehiculeUtilitaire number: 3{}
    	create poidsLourd number: 3{}
    }
}

/*definition of specie building from GIS data with category seach as habitation = living home working = work place or parking = for big car */

species name:building {
    
    string category; 
    rgb color <- #gray ;
    
    aspect base {
    	
    	draw shape color: color;
    }
}

/*definition of specie building form GIS data who contain the road network of the system */

species name:road{
	
    rgb color <- #black;
    geometry display_shape <- shape + 1.5;
    
    aspect base {
    	
    	draw display_shape color: color border: #black;
    }
}

/*definition of species vehicule this one is generic for all vehicule seach as PL, VUL, UP or Motobike */

species name:vehicule skills: [driving]{
	
	rgb color;
	float size;
	int cylindre;
	int carburation;
	float age;
	float max_age;
	float tonage;
	float max_tonage;
	int status;
	capteur observer;
    building home <- nil ;
    building working <- nil ;
    int start;
    int stop;
    int duration;
    float min_speed;
    float max_speed;
    string course; 
    point target <- nil;
    float coeff_emission;
	image_file icon;
	int start_time;
	int count;
	
	/*this reflex define when the car start */
	
	reflex go when: status = 0 and target = nil
	{
		
		if count <  start_time
		{
			count <- count + 1;	
		}
    	if count >= start_time {
    		
	    	if course = "aller"
	    	{
	    		course <- "retour" ;
	    		start_time <- rnd(30, 60);
	    		speed <- min_speed + rnd(max_speed - min_speed);
	    		target <- any_location_in(one_of(building where (each.category='working')));		
	    	}
	    	
	    	if course = "retour"
	    	{
	    		course <- "aller" ;
	    		start_time <- rnd(30, 60);
	    		speed <- min_speed + rnd(max_speed - min_speed);
	    		target <- any_location_in(one_of(building where (each.category='habitation')));
	    	}
	    	count <- 0;
	    }
    }
         
    reflex move when: target != nil {
    	
    	path chemin <- goto(target: target, on: graph_road, return_path: true);
    	
    	list<geometry> segments <- chemin.segments;
    	
    	status <- 1;
		
    	/*le vehicule se connecte toujour au capteur le plus proche de lui lors qu'il se deplace*/
    	
    	observer <- capteur with_min_of (self distance_to each);
    	
	    if target = location {
	        target <- nil ;
	        status <- 0;
	        observer <- nil;
	        duration <- 0;
	    }
    }
    reflex count when: status = 1{
    	
    	duration <- duration + 1;
    }
    reflex age{
    	
    	age <- age + 1;
    	
    	if age >= max_age and status = 0
    	{
    		do die;
    	}
    }
    aspect base{
		
		draw circle(size) color: color;
		
		draw polyline([self.location, observer.location]) color: #slategrey;						
	}
	aspect icon{
		
		draw icon size: size;	
	}
}
species name:deuxRoues parent: vehicule {
	
	float size <- 10.0;
    rgb color <- #blue;
    float age <- 0.0;
    float max_age <- 1 * #y;
    int status <- 0;
	capteur observer;
    float duration;
    float speed;
    float min_speed <- min_speed_moto;
    float max_speed <- max_speed_moto;
    string course; 
    point target <- nil;
   	int cylindre;
   	int carburation <- 1; // 1 = essence
   	float coeff_emission;
   	int count <- 0;
   	int start_time;
    image_file icon;
    
    init{
    	cylindre <- rnd(1, 6);
	    course <- "aller";
	    location <- any_location_in(one_of(building where (each.category='habitation')));
    }  
    reflex coeff_emission when: status = 1{
    	/* for motobike 0.033 en tenant compte de sa taille, carburation, etc.*/
    	
    	coeff_emission <- (age * cylindre * speed * duration * 0.033) #km/#l;
    }
}
species name:vehiculeParticulier parent: vehicule{
	float size <- 15.0;
    rgb color <- #darkturquoise;
    float age <- 0.0;
    float max_age <- 2 * #y;
    int status <- 0;
	capteur observer;
    float duration;
    float speed;
    float min_speed <- min_speed_vp;
    float max_speed <- max_speed_vp;
    string course; 
    point target <- nil;
   	int cylindre;
   	int carburation <- rnd(1,2); //soit 1 = essence ou 2 = mazout
   	float coeff_emission;
   	int count <- 0;
   	int start_time;
   	
   	init{
    	cylindre <- rnd(4, 12);
	    course <- "aller";
	    location <- any_location_in(one_of(building where (each.category='habitation')));
   	}
   	reflex coeff_emission when: status = 1{
    	
    	/* for VP 0.049 en tenant compte de sa carburation et sa taille*/
    	float emission <- 0.0;
    	
    	if(carburation = 1)
    	{ emission <- 0.049;} 
    	else 
    	{emission <- 0.039;}
    	
    	coeff_emission <- (age * cylindre * speed * duration * emission) #km/#l;
    }
}
species name:vehiculeUtilitaire parent: vehicule{
	float size <- 15.0;
    rgb color <- #yellow;
    float age <- 0.0;
    float max_age <- 5 * #y;
    int status;
	capteur observer;
    float duration;
    float speed;
    float min_speed <- min_speed_vul;
    float max_speed <- max_speed_vul;
    string course; 
    point target <- nil;
   	int cylindre;
   	int carburation <- 2; // 2 = mazout
   	float coeff_emission;
   	int count <- 0;
   	int start_time;
   	 	
   	init{
   		cylindre <- rnd(6, 12);
	    course <- "aller";
	    location <- any_location_in(one_of(building where (each.category='habitation')));
   	}
   	reflex coeff_emission when: status = 1{
    	/* for VUL 0.059 */
    	
    	coeff_emission <- (age * cylindre * speed * duration * 0.059) #km/#l;
    }
}
species name:poidsLourd parent: vehicule{
	float size <- 15.0;
    rgb color <- #sienna;
    float age <- 0.0;
    float max_age <- 10 * #y;
    int status <- 0;
	capteur observer;
    float duration;
    float speed;
    float min_speed <- min_speed_pl;
    float max_speed <- max_speed_pl;
    string course; 
    point target <- nil;
   	int cylindre;
   	int carburation <- 2;
   	float coeff_emission;
   	int count <- 0;
    int start_time;
    
    init{
    	cylindre <- rnd(12, 24);
	    course <- "aller";
	    location <- any_location_in(one_of(building where (each.category='working')));
    }  
    reflex coeff_emission when: status = 1{
    	/* for PL 1.2*/
    	
    	coeff_emission <- (age * cylindre * speed * duration * 0.069) #km/#l;
    	
    }
		
}
species name:capteur{
	
	rgb color <- #red;
	float size <- 10.0;
	float qt_gaz_moto <- 0.0;
	float qt_gaz_vp <- 0.0;
	float qt_gaz_vult <- 0.0;
	float qt_gaz_pl <- 0.0;
	list<deuxRoues> moto_observe;
	list<vehiculeParticulier> vp_observe;
	list<vehiculeUtilitaire> vult_observe;
	list<poidsLourd> pl_observe;
	float coeff_tree;
	float rayon_observation <- size * 50;
	
	reflex change_color
	{
		if color = #red {color <- #lime;}
		else{color <- #red;}
	}
	reflex influence_tree{
		
		let tree_observee <- tree select ((each distance_to self) <= rayon_observation);
		
		coeff_tree <- 1.0;
		
		loop el over: tree_observee{
			
			coeff_tree <- coeff_tree + el.power;
		}
	}
	reflex influence_pluie{
		
		ask pluie{
			
			if(self.status = 1)
			{
				myself.qt_gaz_moto <- myself.qt_gaz_moto / self.power;
				myself.qt_gaz_vp <- myself.qt_gaz_vp / self.power;
				myself.qt_gaz_vult <- myself.qt_gaz_vult / self.power;
				myself.qt_gaz_pl <- myself.qt_gaz_pl / self.power;
			}
		}
	}
	reflex influence_vent{
		
		ask vent{
			
			if(self.status = 1)
			{
				myself.qt_gaz_moto <- myself.qt_gaz_moto / self.power;
				myself.qt_gaz_vp <- myself.qt_gaz_vp / self.power;
				myself.qt_gaz_vult <- myself.qt_gaz_vult / self.power;
				myself.qt_gaz_pl <- myself.qt_gaz_pl / self.power;
			}
		}
	}
	
	reflex nbr_vehicule_in_area{
		
		/*le capteur recupere toutes les moto qui roulent dans son rayon et additionne leurs coefficient d'emission*/
		
		let deuxR <- deuxRoues select (each.observer = self);
		qt_gaz_moto <- 0.0;
		
		loop el over: deuxR{
			
			qt_gaz_moto <- qt_gaz_moto + el.coeff_emission;
		}
		qt_gaz_moto <- qt_gaz_moto / coeff_tree;
			
		/*le capteur recupere tous les vehicules particuliers qui roulent dans son rayon et additionne leurs coefficient d'emission */
		
		qt_gaz_vp <- 0.0;
		let vehiculeP <- vehiculeParticulier select (each.observer = self);
		
		loop el over: vehiculeP{
			
			qt_gaz_vp <- qt_gaz_vp + el.coeff_emission;
		}
		qt_gaz_vp <- qt_gaz_vp / coeff_tree;
		
		/*le capteur recupere tous les vehicules utilitaire qui roulent dans son rayon et additionne leurs coefficient d'emission*/
		
		let vehiculeU <- vehiculeUtilitaire select (each.observer = self);
		qt_gaz_vult <- 0.0;
		
		loop el over: vehiculeU{
			
			qt_gaz_vult <- qt_gaz_vult + el.coeff_emission;
		}
		qt_gaz_vult <- qt_gaz_vult / coeff_tree;
		
		/*le capteur recupere tous les vehicules poids lourd qui roulent dans son rayon et additionne leurs coefficient d'emission*/
		
		let poidLourd <- poidsLourd select (each.observer = self);
		
		qt_gaz_pl <- 0.0;
		
		loop el over: poidLourd{
			
			qt_gaz_pl <- qt_gaz_pl + el.coeff_emission;
		}
		qt_gaz_pl <- qt_gaz_pl / coeff_tree;
		
	}
	
	/*chaque apres 5 cycles le capteur envoie un rapport au centre de controle*/
	
	reflex send_info when: every(5#cycles){
		
		ask centre{
			
			self.qt_gaz_moto <- self.qt_gaz_moto + myself.qt_gaz_moto;
			self.qt_gaz_vp <- self.qt_gaz_vp + myself.qt_gaz_vp;
			self.qt_gaz_vult <- self.qt_gaz_vult + myself.qt_gaz_vult;
			self.qt_gaz_pl <- self.qt_gaz_pl + myself.qt_gaz_pl;
		}
	}
	
	aspect base{
		
		draw circle(size) color: color;		
	}
}
species name:centre{
	
	float qt_gaz_moto;
	float qt_gaz_vp;
	float qt_gaz_vult;
	float qt_gaz_pl;
	list<capteur> list_capteur;
	
	reflex update_capteur{
		
		list_capteur <- list(capteur);	
	}	
}
species name:tree{
	float age;
	float max_age <- 45.0;
	float min_size <- 1.0;
	float max_size <- 15.0;
	rgb color <- #green;
	float size <- min_size;
	float power <- 0.0;
	
	/*
	 * the tree can't not done children
	 * the childred done by the system
	 */
	reflex grow_up{
		if(size < max_size)
		{
			size <- size + 0.1;
		}
		age <- age + 0.01;
		power <- age * size;
	}
	/*
	 * if tree come so old die
	 */
	reflex undergrow when: age >= max_age{
		
		size <- size - 0.6;
		power <- age * size;
		
		if(size <= min_size)
		{
			do die;	
		}
	}
	aspect base{
		
		draw circle(size) color: color;
	}
}
species name:vent{
	float power;
	float min_power <- 10.0;
	float max_power <- 1500.0;
	int duration;
	int start_time;
	int count;
	int status;
	
	init{
		power <- 1.0;
		start_time <- rnd(0,23);
		duration <- rnd(1,60);
		status <- 0;
		count <- 0;
	}
	
	reflex set_start when: status = 1{
		
		if(count < duration)
		{
			count <- count + 1;
			power <- rnd(min_power, max_power); // la puissance du vent peut change pendant que le vent souffle
		}
		if(count >= duration)
		{
			status <- 0;
			start_time <- rnd(0,23);
			duration <- rnd(1,60);
			count <- 0;
		}
	}
	reflex status when: status = 0{
		
		start_time <- rnd(0, 23);
	}
	reflex souffle when: (start_time >= 18 or start_time <= 6) and status = 0{
		
		status <- 1;
		power <- min_power + rnd(max_power - min_power);
		duration <- rnd(1,60);
	}
}
species name:pluie{
	float power;
	float quantite;
	float min_qt <- 1.0;
	float max_qt <- 3000.0;
	int duration;
	int start_time;
	int count;
	int status;
	
	init{
		quantite <- 1.0;
		start_time <- rnd(0,23);
		duration <- rnd(1,60);
		status <- 0;
	}
	reflex set_start when: status = 1{
		
		if(count < duration)
		{
			count <- count + 1;
			quantite <- rnd(min_qt, max_qt);
			power <- quantite * duration;
		}
		if(count >= duration)
		{
			start_time <- rnd(0,23);
			status <- 0;
			quantite <- 1.0;		}
	}
	reflex pleuvoir when: (start_time >= 7 or start_time <= 23) and status = 0{
		
		status <- 1;
		quantite <- min_qt + rnd(max_qt - min_qt);
		duration <- rnd(1, 60);
		power <- quantite * duration;
	}	
}
experiment polluation_athmospherique type: gui {
    parameter "Initialize nbr MotoBike :" var: nbr_moto category: "Vehicule";
    parameter "Initialize nbr Vehicule Particulier :" var: nbr_vp category: "Vehicule";
    parameter "Initialeze nbr Vehicule Utilitaire :" var: nbr_vul category: "Vehicule";
    parameter "Initialize nbr Vehicule :" var: nbr_pl category: "Vehicule";
    
    parameter "Initialize nbr tree :" var:nbr_tree category: "Tree";
    
    output {
	    display main_display {
	        species building aspect:base ;
	        species road aspect:base;
	        species capteur aspect:base;
	        species deuxRoues aspect:base;
	        species poidsLourd aspect:base;
	        species vehiculeParticulier aspect:base;
	        species vehiculeUtilitaire aspect:base;
	        species tree aspect:base;
	    }
	    display agent_display refresh: every(3#cycles){
	    	
	    	chart "Observation d'agents" type: histogram size: {0.5, 0.5} position: {0, 0}
	    	{
	    		data "Moto" value: nbrmoto color: #blue;
				data "VP" value: nbrvp color: #dodgerblue;
				data "UTL" value: nbrvult color: #mediumseagreen;
				data "PL" value: nbrpl color: #lawngreen;	
				data "Tree" value: nbrtree color: #green;
	    	}
	    	chart "Observation du Vent et de la Pluie" type: histogram size: {0.5,0.5} position: {0.5,0}
	    	{
	    		data "vent" value: vent max_of each.power color: #deepskyblue;
	    		data "pluie" value: pluie max_of each.power color: #gamablue;
	    	}
	    	chart "Observation de la pollution" type: series size: {1,0.5} position: {0,0.5}
	    	{
	    		data "co2_by_moto" value: centre max_of each.qt_gaz_moto style: line color: #blue;
	    		data "co2_by_vp" value: centre max_of each.qt_gaz_vp style: line color: #dodgerblue;
	    		data "co2_by_vult" value: centre max_of each.qt_gaz_vult style: line color: #mediumseagreen;
	    		data "co2_by_pl" value: centre max_of each.qt_gaz_pl style: line color: #lawngreen;
	    	}
	    }
    }
}